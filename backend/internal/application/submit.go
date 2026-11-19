package application

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/dwmapper"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// 提交编排（backend-design.md 第 4 节）：
//
//	POST /application/submit：校验 → 事务内（applications → SUBMITTED，生成并加密保存 DW username/password，
//	                          插入 dw_users 影子行，dw_user_id 为空）→ 异步编排
//	编排：POST /users（四类核心）→ CREATED → PATCH /users/{id}（其余）→ PATCHED → POST /documents（非美国）→ DOCS_DONE
//	任一步失败记录断点；可重试错误由后台每分钟续传，DW 4xx 等不可自动重试的错误标记 submit_blocked 转人工。

// 编排状态。
const (
	StateCreated  = "CREATED"
	StatePatched  = "PATCHED"
	StateDocsDone = "DOCS_DONE"

	maxSubmitAttempts = 10
)

// DW：编排需要的 DW 能力（*dwclient.Client 满足）。
type DW interface {
	Do(ctx context.Context, method, path string, reqBody, out any) error
}

// OrchApp：编排所需的申请快照。
type OrchApp struct {
	App
	LoginEmail  string
	DWUserID    string
	UsernameEnc []byte
	PasswordEnc []byte
}

// StagedDoc：待上传 DW 的证件。
type StagedDoc struct {
	ID, DocType, Side, ContentType string
	ImageEnc                       []byte
}

// OrchRepo：提交与编排的持久化。
type OrchRepo interface {
	MarkSubmitted(ctx context.Context, appID, ref string, dataEnc, usernameEnc, passwordEnc []byte, now time.Time) error // 非草稿返回 ErrNotDraft
	LoadOrch(ctx context.Context, appID string) (*OrchApp, error)
	SetDWUser(ctx context.Context, appID, dwUserID, state string, now time.Time) error
	SetOrchState(ctx context.Context, appID, state string) error
	RecordAttempt(ctx context.Context, appID, errMsg string, blocked bool, now time.Time) error
	PendingSubmissions(ctx context.Context, retryBefore time.Time, limit int) ([]string, error)
	StagedDocuments(ctx context.Context, appID string) ([]StagedDoc, error)
	MarkDocumentUploaded(ctx context.Context, docID, dwDocumentID string, now time.Time) error
	Audit(ctx context.Context, actor, action, target string, detail map[string]any) error
}

// Orchestrator 执行提交编排。同一申请同时只运行一个编排。
type Orchestrator struct {
	repo    OrchRepo
	dw      DW
	cipher  *crypto.Cipher
	mode    config.UserSubmitMode
	logger  *slog.Logger
	now     func() time.Time
	running sync.Map // appID → struct{}
	// OnUserCreated：DW User 创建后回调（#4 用于立即刷新一次 KYC 状态）。
	OnUserCreated func(ctx context.Context, appID string)
}

// NewOrchestrator 创建编排器。
func NewOrchestrator(repo OrchRepo, dw DW, cipher *crypto.Cipher, mode config.UserSubmitMode, logger *slog.Logger) *Orchestrator {
	if logger == nil {
		logger = slog.Default()
	}
	return &Orchestrator{repo: repo, dw: dw, cipher: cipher, mode: mode, logger: logger, now: time.Now}
}

// WithOrchestrator 启用 POST /application/submit。
func (s *Service) WithOrchestrator(o *Orchestrator, orepo OrchRepo, kycMode config.KYCMode) {
	s.orch, s.orepo, s.kycMode = o, orepo, kycMode
}

func (s *Service) routesSubmit(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	if s.orch == nil {
		return // 未配置 DW 时不注册，由服务器统一返回 50003
	}
	mux.Handle("POST "+prefix+"/application/submit", auth(http.HandlerFunc(s.handleSubmit)))
}

func credAAD(appID, col string) []byte { return crypto.AAD("dw_users", col, appID) }

func (s *Service) handleSubmit(w http.ResponseWriter, r *http.Request) {
	if s.kycMode == config.KYCModePartnerKYC {
		httpx.Fail(w, r, httpx.NotEnabled("当前开户模式暂未开通"))
		return
	}
	var in struct {
		SignatureName string                `json:"signatureName"`
		Disclosures   []dwmapper.Disclosure `json:"disclosures"`
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	ctx := r.Context()
	a, err := s.repo.GetByUser(ctx, httpx.UserID(ctx))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a == nil {
		httpx.Fail(w, r, httpx.Conflict("请先填写开户资料"))
		return
	}
	if a.Status != "DRAFT" {
		httpx.Fail(w, r, httpx.Conflict("开户申请已提交，请勿重复提交"))
		return
	}
	st, err := s.load(a)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	d, err := decodeData(st.Data)
	if err != nil {
		httpx.Fail(w, r, httpx.Validation("开户资料格式不正确，请重新填写"))
		return
	}
	docs, err := s.repo.ListDocuments(ctx, a.ID)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	now := s.now().UTC()
	if fe := ValidateSubmission(d, docs, in.Disclosures, in.SignatureName, now); len(fe) > 0 {
		httpx.Fail(w, r, httpx.Validation("开户资料不完整，请修改标红的内容", fe...))
		return
	}
	// 映射预检：选项无法映射为 DW 取值时现在就拒绝，而不是在异步编排中失败
	if _, _, err := dwmapper.Build(d, dwmapper.Submission{Disclosures: in.Disclosures, SignedBy: in.SignatureName}); err != nil {
		var me *dwmapper.MappingError
		if errors.As(err, &me) {
			var fe []httpx.FieldError
			for _, f := range me.Fields {
				fe = append(fe, httpx.FieldError{Field: f, Reason: "暂不支持该选项，请重新选择"})
			}
			httpx.Fail(w, r, httpx.Validation("", fe...))
			return
		}
		httpx.Fail(w, r, err)
		return
	}

	st.Disclosures = stampDisclosures(in.Disclosures, now)
	st.SignatureName = strings.Join(strings.Fields(in.SignatureName), " ")
	dataEnc, err := s.seal(a.ID, st)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	username, password, err := newDWCredentials()
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	uEnc, err := s.cipher.EncryptString(username, credAAD(a.ID, "dw_username_enc"))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	pEnc, err := s.cipher.EncryptString(password, credAAD(a.ID, "dw_password_enc"))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	ref, err := newApplicationRef(now)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if err := s.orepo.MarkSubmitted(ctx, a.ID, ref, dataEnc, uEnc, pEnc, now); err != nil {
		if errors.Is(err, ErrNotDraft) {
			httpx.Fail(w, r, httpx.Conflict("开户申请已提交，请勿重复提交"))
			return
		}
		httpx.Fail(w, r, err)
		return
	}
	_ = s.orepo.Audit(ctx, "user:"+httpx.UserID(ctx), "application.submitted", "application:"+a.ID, map[string]any{"ref": ref})
	s.logger.InfoContext(ctx, "application submitted", slog.String("application_id", a.ID), slog.String("ref", ref))

	// 异步编排：不阻塞用户；失败由后台续传
	go func(appID string) {
		bg, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		s.orch.Run(bg, appID)
	}(a.ID)

	httpx.OK(w, map[string]any{"applicationRef": ref, "submittedAt": now})
}

// stampDisclosures：缺少确认时间的项补上服务器时间（留痕）。
func stampDisclosures(in []dwmapper.Disclosure, now time.Time) []dwmapper.Disclosure {
	out := make([]dwmapper.Disclosure, len(in))
	for i, d := range in {
		if d.AcceptedAt == "" {
			d.AcceptedAt = now.Format(time.RFC3339)
		}
		out[i] = d
	}
	return out
}

var refEncoding = base32.StdEncoding.WithPadding(base32.NoPadding)

// newApplicationRef：形如 FX261119-7KQ2MDXA，用户可见的申请参考号。
func newApplicationRef(now time.Time) (string, error) {
	b := make([]byte, 5)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return "FX" + now.Format("060102") + "-" + refEncoding.EncodeToString(b), nil
}

// newDWCredentials：DW username/password 由后端生成并加密保管，不向用户展示【Q-DW-4】。
// 规则（长度、字符集）待 DW 确认；当前：用户名 fx + 16 位小写字母数字，密码 24 位含大小写、数字与符号。
func newDWCredentials() (string, string, error) {
	const lower, upper, digits, symbols = "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789", "!@#$%^*-_"
	u, err := randomFrom(lower+digits, 16)
	if err != nil {
		return "", "", err
	}
	var parts []string
	for _, set := range []string{lower, upper, digits, symbols} {
		p, err := randomFrom(set, 3)
		if err != nil {
			return "", "", err
		}
		parts = append(parts, p)
	}
	rest, err := randomFrom(lower+upper+digits+symbols, 12)
	if err != nil {
		return "", "", err
	}
	pw := []byte(strings.Join(parts, "") + rest)
	for i := len(pw) - 1; i > 0; i-- { // 打乱
		j, err := rand.Int(rand.Reader, big.NewInt(int64(i+1)))
		if err != nil {
			return "", "", err
		}
		pw[i], pw[j.Int64()] = pw[j.Int64()], pw[i]
	}
	return "fx" + u, string(pw), nil
}

func randomFrom(set string, n int) (string, error) {
	b := make([]byte, n)
	for i := range b {
		k, err := rand.Int(rand.Reader, big.NewInt(int64(len(set))))
		if err != nil {
			return "", err
		}
		b[i] = set[k.Int64()]
	}
	return string(b), nil
}

// ---------------- 编排 ----------------

// Run 推进一次编排，直到完成或遇到错误。错误只记录，不返回（由后台续传）。
func (o *Orchestrator) Run(ctx context.Context, appID string) {
	if _, busy := o.running.LoadOrStore(appID, struct{}{}); busy {
		return
	}
	defer o.running.Delete(appID)

	err := o.step(ctx, appID)
	blocked := isPermanent(err)
	msg := ""
	if err != nil {
		msg = safeErr(err)
		lvl := slog.LevelWarn
		if blocked {
			lvl = slog.LevelError
		}
		o.logger.Log(ctx, lvl, "submit orchestration failed", slog.String("application_id", appID), slog.String("error", msg), slog.Bool("blocked", blocked))
	}
	if rerr := o.repo.RecordAttempt(ctx, appID, msg, blocked, o.now().UTC()); rerr != nil {
		o.logger.ErrorContext(ctx, "record attempt failed", slog.String("application_id", appID), slog.String("error", rerr.Error()))
	}
}

func (o *Orchestrator) step(ctx context.Context, appID string) error {
	a, err := o.repo.LoadOrch(ctx, appID)
	if err != nil {
		return err
	}
	if a == nil || a.Status == "DRAFT" || a.SubmitBlocked || a.OrchState == StateDocsDone {
		return nil
	}
	pt, err := o.cipher.Decrypt(a.DataEnc, dataAAD(a.ID))
	if err != nil {
		return err
	}
	var st stored
	if err := json.Unmarshal(pt, &st); err != nil {
		return err
	}
	d, err := decodeData(st.Data)
	if err != nil {
		return err
	}
	core, rest, err := dwmapper.Build(d, dwmapper.Submission{Disclosures: st.Disclosures, SignedBy: st.SignatureName, LoginEmail: a.LoginEmail})
	if err != nil {
		return permanent{err}
	}

	// Step 1：POST /users
	if a.DWUserID == "" {
		username, err := o.cipher.DecryptString(a.UsernameEnc, credAAD(a.ID, "dw_username_enc"))
		if err != nil {
			return err
		}
		password, err := o.cipher.DecryptString(a.PasswordEnc, credAAD(a.ID, "dw_password_enc"))
		if err != nil {
			return err
		}
		docs, next := core, StateCreated
		if o.mode == config.SubmitSinglePost {
			docs, next = append(append([]dwmapper.Document{}, core...), rest...), StatePatched
		}
		var resp map[string]any
		if err := o.dw.Do(ctx, http.MethodPost, "/users", dwmapper.CreateUserBody(username, password, docs), &resp); err != nil {
			return err
		}
		id := firstString(resp, "id", "userID", "userId")
		if id == "" {
			return permanent{errors.New("DW 创建用户响应中没有用户 id（字段名待沙盒验证）")}
		}
		if err := o.repo.SetDWUser(ctx, a.ID, id, next, o.now().UTC()); err != nil {
			return err
		}
		_ = o.repo.Audit(ctx, "system", "dw.user.created", "application:"+a.ID, map[string]any{"dw_user_id": id, "mode": string(o.mode)})
		o.logger.InfoContext(ctx, "dw user created", slog.String("application_id", a.ID), slog.String("dw_user_id", id))
		a.DWUserID, a.OrchState = id, next
		if o.OnUserCreated != nil {
			o.OnUserCreated(ctx, a.ID)
		}
	}

	// Step 2：PATCH /users/{id}
	if a.OrchState == StateCreated {
		if err := o.dw.Do(ctx, http.MethodPatch, "/users/"+a.DWUserID, dwmapper.PatchUserBody(rest), nil); err != nil {
			return err
		}
		if err := o.repo.SetOrchState(ctx, a.ID, StatePatched); err != nil {
			return err
		}
		a.OrchState = StatePatched
	}

	// Step 3：POST /documents（仅非美国纳税人有暂存证件；请求体字段待沙盒验证）
	if a.OrchState == StatePatched {
		docs, err := o.repo.StagedDocuments(ctx, a.ID)
		if err != nil {
			return err
		}
		for _, doc := range docs {
			img, err := o.cipher.Decrypt(doc.ImageEnc, docAAD(a.ID, doc.Side))
			if err != nil {
				return err
			}
			body := map[string]any{"userID": a.DWUserID, "type": doc.DocType, "side": doc.Side, "document": base64.StdEncoding.EncodeToString(img)}
			var resp map[string]any
			if err := o.dw.Do(ctx, http.MethodPost, "/documents", body, &resp); err != nil {
				return err
			}
			if err := o.repo.MarkDocumentUploaded(ctx, doc.ID, firstString(resp, "id", "documentID"), o.now().UTC()); err != nil {
				return err
			}
		}
		if err := o.repo.SetOrchState(ctx, a.ID, StateDocsDone); err != nil {
			return err
		}
		_ = o.repo.Audit(ctx, "system", "application.orchestration.done", "application:"+a.ID, nil)
	}
	return nil
}

// Start 后台续传：每分钟处理未完成且可重试的提交。
func (o *Orchestrator) Start(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			ids, err := o.repo.PendingSubmissions(ctx, o.now().Add(-every), 20)
			if err != nil {
				o.logger.ErrorContext(ctx, "list pending submissions failed", slog.String("error", err.Error()))
				continue
			}
			for _, id := range ids {
				o.Run(ctx, id)
			}
		}
	}
}

// permanent：不可自动重试的错误（转人工）。
type permanent struct{ error }

func (p permanent) Unwrap() error { return p.error }

// isPermanent：DW 4xx（429 除外）与映射错误不自动重试；网络错误、5xx、429 可重试。
// 注意：POST /users 超时后重试会用同一 username，若 DW 实际已创建会返回 4xx → 转人工，不会重复创建。
func isPermanent(err error) bool {
	if err == nil {
		return false
	}
	var p permanent
	if errors.As(err, &p) {
		return true
	}
	var ae *dwclient.APIError
	if errors.As(err, &ae) {
		return ae.Status >= 400 && ae.Status < 500 && ae.Status != http.StatusTooManyRequests && ae.Status != http.StatusUnauthorized
	}
	return false
}

// safeErr：只保留状态码与 DW 错误码，不保存 DW 返回的消息原文（可能回显 PII）。
func safeErr(err error) string {
	var ae *dwclient.APIError
	if errors.As(err, &ae) {
		s := fmt.Sprintf("DW HTTP %d", ae.Status)
		if ae.DWCode != "" {
			s += " code=" + ae.DWCode
		}
		if ae.RequestID != "" {
			s += " requestId=" + ae.RequestID
		}
		return s
	}
	var p permanent
	if errors.As(err, &p) {
		return p.Error()
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "timeout"
	}
	return "internal error"
}

func firstString(m map[string]any, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k].(string); ok && v != "" {
			return v
		}
	}
	return ""
}
