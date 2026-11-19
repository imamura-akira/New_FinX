// Package application：开户草稿、提交编排与开户进度（api-spec.md 第 2 节，F2–F4）。
package application

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"reflect"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
	"github.com/imamura-akira/New_FinX/backend/internal/dwmapper"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// stored：data_enc 解密后的结构。
type stored struct {
	Data          map[string]json.RawMessage `json:"data"`
	Disclosures   []dwmapper.Disclosure      `json:"disclosures,omitempty"`
	SignatureName string                     `json:"signatureName,omitempty"`
}

// 草稿与证件上传的限制。
const (
	maxDraftBytes    = 64 << 10
	maxImageBytes    = 10 << 20
	maxDocumentBody  = maxImageBytes*4/3 + 4096 // base64 膨胀
	maskedTINRune    = '•'
	maskedTINVisible = 4
)

// 合法的步骤标识（P-03a–g、P-04、P-05、P-30）。
var validSteps = map[string]bool{"a": true, "b": true, "c": true, "d": true, "e": true, "f": true, "g": true, "p04": true, "p05": true, "p30": true}

// 证件类型（pages.md 3.1.3；以 DW 支持为准，待沙盒验证）。
var validDocTypes = map[string]bool{"PASSPORT": true, "DRIVER_LICENSE": true, "NATIONAL_ID_CARD": true, "RESIDENCE_PERMIT": true}

var validImageTypes = map[string]bool{"image/jpeg": true, "image/png": true, "application/pdf": true}

// allowedKeys：ApplicationData 的字段名（与 dwmapper.Data 的 JSON 标签一致，契约测试保证与 openapi 一致）。
var allowedKeys = func() map[string]bool {
	m := map[string]bool{}
	t := reflect.TypeOf(dwmapper.Data{})
	for i := 0; i < t.NumField(); i++ {
		m[strings.Split(t.Field(i).Tag.Get("json"), ",")[0]] = true
	}
	return m
}()

// Service：开户申请模块。
type Service struct {
	repo   Repo
	cipher *crypto.Cipher
	logger *slog.Logger
	now    func() time.Time
	orch   *Orchestrator // 提交编排（#3）；nil 时 submit 返回 50003
}

// New 创建模块。
func New(repo Repo, cipher *crypto.Cipher, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{repo: repo, cipher: cipher, logger: logger, now: time.Now}
}

// Routes 注册 /application 系列接口；auth 为鉴权中间件。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	mux.Handle("GET "+prefix+"/application", auth(http.HandlerFunc(s.handleGet)))
	mux.Handle("PUT "+prefix+"/application/draft", auth(http.HandlerFunc(s.handleSaveDraft)))
	mux.Handle("POST "+prefix+"/application/documents", auth(http.HandlerFunc(s.handleUploadDocument)))
	s.routesSubmit(mux, prefix, auth)
}

func dataAAD(appID string) []byte { return crypto.AAD("applications", "data_enc", appID) }

func docAAD(appID, side string) []byte {
	return crypto.AAD("application_documents", "image_enc", appID+":"+side)
}

func (s *Service) load(a *App) (stored, error) {
	st := stored{Data: map[string]json.RawMessage{}}
	if a == nil || len(a.DataEnc) == 0 {
		return st, nil
	}
	pt, err := s.cipher.Decrypt(a.DataEnc, dataAAD(a.ID))
	if err != nil {
		return st, err
	}
	if err := json.Unmarshal(pt, &st); err != nil {
		return st, err
	}
	if st.Data == nil {
		st.Data = map[string]json.RawMessage{}
	}
	return st, nil
}

func (s *Service) seal(appID string, st stored) ([]byte, error) {
	pt, err := json.Marshal(st)
	if err != nil {
		return nil, err
	}
	return s.cipher.Encrypt(pt, dataAAD(appID))
}

// ---------- GET /application ----------

type kycView struct {
	Status    string     `json:"status"`
	UpdatedAt *time.Time `json:"updatedAt"`
}

type appView struct {
	ApplicationID *string                    `json:"applicationId"`
	Status        string                     `json:"status"`
	Step          *string                    `json:"step"`
	Data          map[string]json.RawMessage `json:"data"`
	Disclosures   []dwmapper.Disclosure      `json:"disclosures"`
	KYC           *kycView                   `json:"kyc"`
	Documents     []DocMeta                  `json:"documents"` // 新增字段（api-spec.md 第 10 节登记）：已暂存证件，供断点续填
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request) {
	a, err := s.repo.GetByUser(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	v := appView{Status: "NONE", Data: map[string]json.RawMessage{}, Disclosures: []dwmapper.Disclosure{}, Documents: []DocMeta{}}
	if a == nil {
		httpx.OK(w, v)
		return
	}
	st, err := s.load(a)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	v.ApplicationID, v.Status, v.Data = &a.ID, a.Status, maskData(st.Data)
	if a.Step != "" {
		v.Step = &a.Step
	}
	if st.Disclosures != nil {
		v.Disclosures = st.Disclosures
	}
	if v.Documents, err = s.repo.ListDocuments(r.Context(), a.ID); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	k, err := s.repo.KYC(r.Context(), a.ID)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if k != nil {
		v.KYC = &kycView{Status: k.Status, UpdatedAt: k.UpdatedAt}
	}
	httpx.OK(w, v)
}

// maskData：税号只返回后 4 位（读取时打码；客户端回传打码值视为未修改）。
func maskData(d map[string]json.RawMessage) map[string]json.RawMessage {
	out := make(map[string]json.RawMessage, len(d))
	for k, v := range d {
		out[k] = v
	}
	if raw, ok := d["tin"]; ok {
		var tin string
		if json.Unmarshal(raw, &tin) == nil {
			out["tin"], _ = json.Marshal(MaskTIN(tin))
		}
	}
	return out
}

// MaskTIN：只保留最后 4 个字母数字，其余替换为 •。
func MaskTIN(tin string) string {
	var b strings.Builder
	alnum := 0
	for _, r := range tin {
		if isAlnum(r) {
			alnum++
		}
	}
	seen := 0
	for _, r := range tin {
		if !isAlnum(r) {
			b.WriteRune(r)
			continue
		}
		seen++
		if seen > alnum-maskedTINVisible {
			b.WriteRune(r)
		} else {
			b.WriteRune(maskedTINRune)
		}
	}
	return b.String()
}

func isAlnum(r rune) bool {
	return (r >= '0' && r <= '9') || (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
}

// ---------- PUT /application/draft ----------

func (s *Service) handleSaveDraft(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Step string                     `json:"step"`
		Data map[string]json.RawMessage `json:"data"`
	}
	if err := httpx.Decode(w, r, maxDraftBytes, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if !validSteps[in.Step] {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "step", Reason: "步骤标识不正确"}))
		return
	}
	a, err := s.repo.EnsureDraft(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a.Status != "DRAFT" {
		httpx.Fail(w, r, httpx.Conflict("开户申请已提交，不能再修改"))
		return
	}
	st, err := s.load(a)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	merged, ferr := mergeDraft(st.Data, in.Data)
	if ferr != nil {
		httpx.Fail(w, r, ferr)
		return
	}
	st.Data = merged
	enc, err := s.seal(a.ID, st)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	now := s.now().UTC()
	if err := s.repo.SaveDraft(r.Context(), a.ID, in.Step, enc, now); err != nil {
		if errors.Is(err, ErrNotDraft) {
			httpx.Fail(w, r, httpx.Conflict("开户申请已提交，不能再修改"))
			return
		}
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, map[string]any{"savedAt": now})
}

// mergeDraft：顶层字段浅合并。null 删除字段；不在 ApplicationData 中的字段丢弃；
// 税号为打码值（含 •）时视为未修改；合并结果必须能按 ApplicationData 的类型解析。
func mergeDraft(cur, patch map[string]json.RawMessage) (map[string]json.RawMessage, error) {
	out := make(map[string]json.RawMessage, len(cur)+len(patch))
	for k, v := range cur {
		out[k] = v
	}
	for k, v := range patch {
		if !allowedKeys[k] {
			continue
		}
		if bytes.Equal(bytes.TrimSpace(v), []byte("null")) {
			delete(out, k)
			continue
		}
		if k == "tin" {
			var tin string
			if json.Unmarshal(v, &tin) == nil && strings.ContainsRune(tin, maskedTINRune) {
				continue
			}
		}
		out[k] = v
	}
	// 类型检查：逐字段解析，定位到具体字段
	for k, v := range out {
		probe, _ := json.Marshal(map[string]json.RawMessage{k: v})
		var d dwmapper.Data
		if err := json.Unmarshal(probe, &d); err != nil {
			return nil, httpx.Validation("", httpx.FieldError{Field: k, Reason: "字段格式不正确"})
		}
	}
	// 账户类型首期固定，不接受客户端改写
	for k, fixed := range map[string]string{"accountType": "LIVE", "tradingType": "CASH", "accountManagementType": "SELF"} {
		out[k], _ = json.Marshal(fixed)
	}
	return out, nil
}

// ---------- POST /application/documents ----------

func (s *Service) handleUploadDocument(w http.ResponseWriter, r *http.Request) {
	var in struct {
		DocType string `json:"docType"`
		Side    string `json:"side"`
		Image   string `json:"image"`
	}
	if err := httpx.Decode(w, r, maxDocumentBody, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	var fe []httpx.FieldError
	if !validDocTypes[in.DocType] {
		fe = append(fe, httpx.FieldError{Field: "docType", Reason: "请选择证件类型"})
	}
	if in.Side != "FRONT" && in.Side != "BACK" {
		fe = append(fe, httpx.FieldError{Field: "side", Reason: "请指定证件正面或背面"})
	}
	img, err := base64.StdEncoding.DecodeString(in.Image)
	ctype := ""
	switch {
	case err != nil || len(img) == 0:
		fe = append(fe, httpx.FieldError{Field: "image", Reason: "图片无法读取，请重新拍摄或上传"})
	case len(img) > maxImageBytes:
		fe = append(fe, httpx.FieldError{Field: "image", Reason: "图片不能超过 10 MB"})
	default:
		ctype = http.DetectContentType(img)
		if !validImageTypes[ctype] {
			fe = append(fe, httpx.FieldError{Field: "image", Reason: "仅支持 JPG、PNG 或 PDF"})
		}
	}
	if in.DocType == "PASSPORT" && in.Side == "BACK" {
		fe = append(fe, httpx.FieldError{Field: "side", Reason: "护照只需上传资料页"})
	}
	if len(fe) > 0 {
		httpx.Fail(w, r, httpx.Validation("", fe...))
		return
	}
	a, err := s.repo.EnsureDraft(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a.Status != "DRAFT" { // 提交后补证件走 P-35（KYC_DOC_REQUIRED），本期未实现
		httpx.Fail(w, r, httpx.Conflict("开户申请已提交，不能再修改证件"))
		return
	}
	enc, err := s.cipher.Encrypt(img, docAAD(a.ID, in.Side))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	id, err := s.repo.PutDocument(r.Context(), a.ID, in.DocType, in.Side, ctype, enc)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	s.logger.InfoContext(r.Context(), "document stored", slog.String("application_id", a.ID), slog.String("doc_type", in.DocType), slog.String("side", in.Side), slog.Int("bytes", len(img)))
	httpx.OK(w, map[string]string{"documentId": id})
}

// decodeData 把草稿解析为 dwmapper.Data（提交校验与映射使用）。
func decodeData(m map[string]json.RawMessage) (dwmapper.Data, error) {
	var d dwmapper.Data
	raw, err := json.Marshal(m)
	if err != nil {
		return d, err
	}
	err = json.Unmarshal(raw, &d)
	return d, err
}
