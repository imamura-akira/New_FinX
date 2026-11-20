// Command demoreset：演示辅助工具（Demo-1 #12，仅 sandbox）。
//
//	list                                  列出本地演示用户（邮箱、申请 / KYC / 账户状态、银行数）
//	reset  -email <邮箱> [-yes]           删除该用户在本地数据库中的全部记录，以便用同一邮箱重新演示开户。
//	                                      不带 -yes 时只预览将删除的条数。不会删除或修改 DW 沙盒中的数据。
//	import -email <邮箱> -dw-user <id>    从 DW 沙盒读取已有测试用户（姓名、KYC、账户），在本地重建关联；
//	       [-bank-id <id> -bank-mask <4位> -bank-type CHECKING|SAVINGS -bank-nickname <名>]
//	import -local <label>                 同上，参数取自 backend/demo-users.local.json（已 gitignore）
//	verify -email <邮箱> | -dw-user <id>  演示验真：直接调 DW 沙盒 GET /users/{id}、kyc-status、/accounts、money summary，
//	                                      原样打印 DW 返回的编号与状态，与 App"DW 沙盒凭证"区当场对照。
//	                                      -email 只用本地库查出 DW 用户 id，其余数据全部来自 DW（不读本地库）。
//
// 虚拟行情（marketsim）用固定种子在服务启动时初始化：重启服务即重置行情。
//
// 运行：set -a; source .env; set +a; go run ./cmd/demoreset <子命令> ...
// 输出不打印 PII 与完整账户号码（账户号只显示尾号）。
package main

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/base32"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	cmd, args := os.Args[1], os.Args[2:]
	cfg, err := config.Load()
	if err != nil {
		fail("配置无效：%v", err)
	}
	if cfg.Env != "sandbox" {
		fail("demoreset 只能在 APP_ENV=sandbox 下运行")
	}
	if cfg.DatabaseURL == "" {
		fail("需要 DATABASE_URL")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	st, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		fail("数据库连接失败：%v", err)
	}
	defer st.Close()

	switch cmd {
	case "list":
		err = list(ctx, st.DB)
	case "reset":
		fs := flag.NewFlagSet("reset", flag.ExitOnError)
		email := fs.String("email", "", "演示用户邮箱")
		yes := fs.Bool("yes", false, "确认删除（不带则只预览）")
		_ = fs.Parse(args)
		err = reset(ctx, st.DB, *email, *yes)
	case "import":
		fs := flag.NewFlagSet("import", flag.ExitOnError)
		in := importInput{}
		local := fs.String("local", "", "从 demo-users.local.json 读取的 label")
		fs.StringVar(&in.Email, "email", "", "本地登录邮箱")
		fs.StringVar(&in.DWUser, "dw-user", "", "DW 沙盒用户 id")
		fs.StringVar(&in.BankID, "bank-id", "", "DW 银行账户 id（可选）")
		fs.StringVar(&in.BankMask, "bank-mask", "", "银行账号尾号 4 位（可选）")
		fs.StringVar(&in.BankType, "bank-type", "CHECKING", "CHECKING 或 SAVINGS")
		fs.StringVar(&in.BankNickname, "bank-nickname", "", "银行备注名（可选）")
		_ = fs.Parse(args)
		if *local != "" {
			if in, err = fromLocal(*local); err != nil {
				break
			}
		}
		err = runImport(ctx, cfg, st.DB, in)
	case "verify":
		fs := flag.NewFlagSet("verify", flag.ExitOnError)
		email := fs.String("email", "", "本地登录邮箱（仅用于查出 DW 用户 id）")
		dwUser := fs.String("dw-user", "", "直接指定 DW 用户 id（完全不读本地库）")
		_ = fs.Parse(args)
		err = verify(ctx, cfg, st.DB, *email, *dwUser, os.Stdout)
	default:
		usage()
	}
	if err != nil {
		fail("%v", err)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "用法：demoreset list | reset -email X [-yes] | import (-local LABEL | -email X -dw-user ID [-bank-id ...]) | verify (-email X | -dw-user ID)")
	os.Exit(2)
}

func fail(format string, a ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", a...)
	os.Exit(1)
}

func tail4(s string) string {
	if len(s) <= 4 {
		return s
	}
	return "…" + s[len(s)-4:]
}

// ---------- list ----------

func list(ctx context.Context, db *sql.DB) error {
	rows, err := db.QueryContext(ctx, `
		SELECT u.email, coalesce(a.status, 'NONE'), coalesce(d.kyc_status, '—'), coalesce(ac.status, '—'), coalesce(ac.account_no, ''),
		       (SELECT count(*) FROM bank_accounts b WHERE b.account_id = ac.id AND b.deleted_at IS NULL)
		  FROM users_app u
		  LEFT JOIN applications a ON a.user_id = u.id AND a.deleted_at IS NULL
		  LEFT JOIN dw_users d ON d.application_id = a.id
		  LEFT JOIN accounts ac ON ac.dw_user_id = d.dw_user_id
		 WHERE u.deleted_at IS NULL
		 ORDER BY u.created_at`)
	if err != nil {
		return err
	}
	defer rows.Close()
	fmt.Printf("%-34s %-10s %-18s %-8s %-7s %s\n", "邮箱", "申请", "KYC", "账户", "账号", "银行")
	for rows.Next() {
		var email, app, kyc, acct, no string
		var banks int
		if err := rows.Scan(&email, &app, &kyc, &acct, &no, &banks); err != nil {
			return err
		}
		fmt.Printf("%-34s %-10s %-18s %-8s %-7s %d\n", email, app, kyc, acct, tail4(no), banks)
	}
	return rows.Err()
}

// ---------- reset ----------

// resetSteps：按外键依赖从叶到根删除（$1 = user id）。
var resetSteps = []struct{ table, sql string }{
	{"orders", `DELETE FROM orders WHERE account_id IN (SELECT ac.id FROM accounts ac JOIN dw_users d ON d.dw_user_id = ac.dw_user_id JOIN applications a ON a.id = d.application_id WHERE a.user_id = $1) OR created_by = $1`},
	{"transfers", `DELETE FROM transfers WHERE account_id IN (SELECT ac.id FROM accounts ac JOIN dw_users d ON d.dw_user_id = ac.dw_user_id JOIN applications a ON a.id = d.application_id WHERE a.user_id = $1) OR created_by = $1`},
	{"bank_accounts", `DELETE FROM bank_accounts WHERE account_id IN (SELECT ac.id FROM accounts ac JOIN dw_users d ON d.dw_user_id = ac.dw_user_id JOIN applications a ON a.id = d.application_id WHERE a.user_id = $1)`},
	{"accounts", `DELETE FROM accounts WHERE dw_user_id IN (SELECT d.dw_user_id FROM dw_users d JOIN applications a ON a.id = d.application_id WHERE a.user_id = $1)`},
	{"kyc_issues", `DELETE FROM kyc_issues WHERE dw_user_id IN (SELECT d.dw_user_id FROM dw_users d JOIN applications a ON a.id = d.application_id WHERE a.user_id = $1)`},
	{"documents_meta", `DELETE FROM documents_meta WHERE dw_user_id IN (SELECT d.dw_user_id FROM dw_users d JOIN applications a ON a.id = d.application_id WHERE a.user_id = $1)`},
	{"dw_users", `DELETE FROM dw_users WHERE application_id IN (SELECT id FROM applications WHERE user_id = $1)`},
	{"application_documents", `DELETE FROM application_documents WHERE application_id IN (SELECT id FROM applications WHERE user_id = $1)`},
	{"applications", `DELETE FROM applications WHERE user_id = $1`},
	{"sessions", `DELETE FROM sessions WHERE user_id = $1`},
	{"users_app", `DELETE FROM users_app WHERE id = $1`},
}

func reset(ctx context.Context, db *sql.DB, email string, yes bool) error {
	email = strings.TrimSpace(email)
	if email == "" {
		return errors.New("需要 -email")
	}
	var uid string
	if err := db.QueryRowContext(ctx, `SELECT id FROM users_app WHERE lower(email) = lower($1) AND deleted_at IS NULL`, email).Scan(&uid); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("本地没有用户 %s", email)
		}
		return err
	}
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	for _, s := range resetSteps {
		res, err := tx.ExecContext(ctx, s.sql, uid)
		if err != nil {
			return fmt.Errorf("%s：%w", s.table, err)
		}
		n, _ := res.RowsAffected()
		fmt.Printf("  %-22s %d\n", s.table, n)
	}
	if !yes {
		fmt.Println("预览完成（已回滚，未删除）。确认删除请加 -yes。DW 沙盒中的用户与账户不受影响。")
		return nil
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	if err := store.Audit(ctx, db, "demoreset", "demo.reset", uid, map[string]any{"tables": len(resetSteps)}); err != nil {
		return err
	}
	fmt.Printf("已删除 %s 的本地记录。可用同一邮箱重新登录并演示开户（DW 沙盒中的旧用户仍保留）。\n", email)
	return nil
}

// ---------- import ----------

type importInput struct {
	Email, DWUser                            string
	BankID, BankMask, BankType, BankNickname string
}

func fromLocal(label string) (importInput, error) {
	b, err := os.ReadFile("demo-users.local.json")
	if err != nil {
		return importInput{}, fmt.Errorf("读取 demo-users.local.json 失败（请在 backend 目录运行）：%w", err)
	}
	// 文件字段为 camelCase（dwUserId 等），这里手动映射
	var raw struct {
		Users []map[string]any `json:"users"`
	}
	if err := json.Unmarshal(b, &raw); err != nil {
		return importInput{}, err
	}
	for _, u := range raw.Users {
		if s(u["label"]) == label {
			return importInput{
				Email: s(u["email"]), DWUser: s(u["dwUserId"]),
				BankID: s(u["dwBankId"]), BankMask: s(u["bankMask"]), BankType: s(u["bankType"]), BankNickname: s(u["nickname"]),
			}, nil
		}
	}
	return importInput{}, fmt.Errorf("demo-users.local.json 中没有 label=%s", label)
}

func s(v any) string {
	if v == nil {
		return ""
	}
	return fmt.Sprint(v)
}

var maskRE = regexp.MustCompile(`^[0-9]{4}$`)

// dwUser：GET /users/{id} 中导入需要的字段（姓名可能在顶层或 BASIC_INFO 文档中）。
type dwUser struct {
	FirstName string `json:"firstName"`
	LastName  string `json:"lastName"`
	Documents []struct {
		Type string                     `json:"type"`
		Data map[string]json.RawMessage `json:"data"`
	} `json:"documents"`
	UserDetails *struct {
		FirstName string `json:"firstName"`
		LastName  string `json:"lastName"`
	} `json:"userDetails"`
}

func (u dwUser) name() (string, string) {
	if u.FirstName != "" {
		return u.FirstName, u.LastName
	}
	if u.UserDetails != nil && u.UserDetails.FirstName != "" {
		return u.UserDetails.FirstName, u.UserDetails.LastName
	}
	for _, d := range u.Documents {
		if d.Type == "BASIC_INFO" {
			var f, l string
			_ = json.Unmarshal(d.Data["firstName"], &f)
			_ = json.Unmarshal(d.Data["lastName"], &l)
			return f, l
		}
	}
	return "", ""
}

type dwAccount struct {
	ID          string `json:"id"`
	AccountNo   string `json:"accountNo"`
	Status      any    `json:"status"`
	AccountType any    `json:"accountType"`
	Opened      string `json:"openedWhen"`
}

func nameOf(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case map[string]any:
		if n, ok := t["name"].(string); ok {
			return n
		}
	}
	return ""
}

func runImport(ctx context.Context, cfg *config.Config, db *sql.DB, in importInput) error {
	in.Email = strings.TrimSpace(in.Email)
	if in.Email == "" || in.DWUser == "" {
		return errors.New("需要 -email 与 -dw-user（或 -local）")
	}
	if in.BankID != "" && (!maskRE.MatchString(in.BankMask) || (in.BankType != "CHECKING" && in.BankType != "SAVINGS")) {
		return errors.New("导入银行账户需要 -bank-mask（4 位数字）与 -bank-type CHECKING|SAVINGS")
	}
	if !cfg.DWConfigured() || cfg.PIIKey == nil {
		return errors.New("需要 DW 凭据与 PII_ENCRYPTION_KEY")
	}
	cipher, err := crypto.New(cfg.PIIKey)
	if err != nil {
		return err
	}
	dw, err := dwclient.New(dwclient.Config{
		BaseURL: cfg.DW.BaseURL, AppKey: cfg.DW.AppKey, ClientID: cfg.DW.ClientID, ClientSecret: cfg.DW.ClientSecret,
		Timeout: cfg.DW.HTTPTimeout, TokenRequestsPerHour: cfg.DW.TokenRequestsPerHour, TokenRefreshSkew: cfg.DW.TokenRefreshSkew,
	})
	if err != nil {
		return err
	}

	// 1) 从 DW 读取（只读）
	var u dwUser
	if err := dw.Do(ctx, "GET", "/users/"+in.DWUser, nil, &u); err != nil {
		return fmt.Errorf("读取 DW 用户失败：%w", err)
	}
	first, last := u.name()
	if first == "" || last == "" {
		return errors.New("DW 用户资料中没有姓名，无法导入")
	}
	var kyc struct {
		Status any `json:"status"`
		KYC    *struct {
			Status any `json:"status"`
		} `json:"kyc"`
	}
	if err := dw.Do(ctx, "GET", "/users/"+in.DWUser+"/kyc-status", nil, &kyc); err != nil {
		return fmt.Errorf("读取 KYC 状态失败：%w", err)
	}
	kycStatus := "KYC_" + strings.TrimPrefix(nameOf(kyc.Status), "KYC_")
	if kyc.KYC != nil && nameOf(kyc.KYC.Status) != "" {
		kycStatus = "KYC_" + strings.TrimPrefix(nameOf(kyc.KYC.Status), "KYC_")
	}
	var accts []dwAccount
	if err := dw.Do(ctx, "GET", "/users/"+in.DWUser+"/accounts", nil, &accts); err != nil {
		return fmt.Errorf("读取账户失败：%w", err)
	}
	var acct *dwAccount
	for i := range accts {
		if strings.EqualFold(nameOf(accts[i].AccountType), "LIVE") || nameOf(accts[i].AccountType) == "" {
			acct = &accts[i]
			break
		}
	}
	if acct == nil {
		return errors.New("该 DW 用户没有 LIVE 账户，无法导入")
	}
	acctStatus := nameOf(acct.Status)
	switch acctStatus {
	case "OPEN", "OPEN_NO_NEW_TRADES", "FROZEN", "CLOSED", "PENDING":
	default:
		return fmt.Errorf("不支持的账户状态 %q", acctStatus)
	}
	var opened *time.Time
	if t, err := time.Parse(time.RFC3339, acct.Opened); err == nil {
		opened = &t
	}

	// 2) 写入本地（单事务）
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	var exists int
	if err := tx.QueryRowContext(ctx, `SELECT count(*) FROM dw_users WHERE dw_user_id = $1`, in.DWUser).Scan(&exists); err != nil {
		return err
	}
	if exists > 0 {
		return errors.New("该 DW 用户已关联到本地用户（可先用 list 查看，或 reset 后再导入）")
	}
	var uid string
	err = tx.QueryRowContext(ctx, `SELECT id FROM users_app WHERE lower(email) = lower($1) AND deleted_at IS NULL`, in.Email).Scan(&uid)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		if err := tx.QueryRowContext(ctx, `INSERT INTO users_app (email) VALUES ($1) RETURNING id`, in.Email).Scan(&uid); err != nil {
			return err
		}
	case err != nil:
		return err
	default:
		var n int
		if err := tx.QueryRowContext(ctx, `SELECT count(*) FROM applications WHERE user_id = $1 AND status <> 'DRAFT'`, uid).Scan(&n); err != nil {
			return err
		}
		if n > 0 {
			return errors.New("该邮箱已有提交过的申请，请换一个邮箱或先 reset")
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM application_documents WHERE application_id IN (SELECT id FROM applications WHERE user_id = $1)`, uid); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM applications WHERE user_id = $1`, uid); err != nil {
			return err
		}
	}

	now := time.Now().UTC()
	ref, err := newRef(now)
	if err != nil {
		return err
	}
	var appID string
	if err := tx.QueryRowContext(ctx, `
		INSERT INTO applications (user_id, status, step, application_ref, orchestration_state, submitted_at)
		VALUES ($1, 'APPROVED', 'p30', $2, 'DOCS_DONE', $3) RETURNING id`, uid, ref, now).Scan(&appID); err != nil {
		return err
	}
	// 申请资料只写姓名（资金模块用于绑卡户名与 WIRE 收款人），按服务端格式与 AAD 加密
	data, _ := json.Marshal(map[string]any{"data": map[string]string{"firstName": first, "lastName": last}})
	enc, err := cipher.Encrypt(data, crypto.AAD("applications", "data_enc", appID))
	if err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE applications SET data_enc = $2 WHERE id = $1`, appID, enc); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO dw_users (application_id, dw_user_id, kyc_status, kyc_updated_at, kyc_checked_at)
		VALUES ($1, $2, $3, $4, $4)`, appID, in.DWUser, kycStatus, now); err != nil {
		return fmt.Errorf("dw_users：%w", err)
	}
	var accountID string
	if err := tx.QueryRowContext(ctx, `
		INSERT INTO accounts (dw_user_id, dw_account_id, account_no, status, opened_at)
		VALUES ($1, $2, $3, $4, $5) RETURNING id`, in.DWUser, acct.ID, acct.AccountNo, acctStatus, opened).Scan(&accountID); err != nil {
		return fmt.Errorf("accounts：%w", err)
	}
	if in.BankID != "" {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO bank_accounts (account_id, dw_bank_account_id, mask, type, owner_name, status, nickname)
			VALUES ($1, $2, $3, $4, $5, 'ACTIVE', nullif($6, ''))`,
			accountID, in.BankID, in.BankMask, in.BankType, first+" "+last, in.BankNickname); err != nil {
			return fmt.Errorf("bank_accounts：%w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	if err := store.Audit(ctx, db, "demoreset", "demo.import", uid, map[string]any{"bank": in.BankID != ""}); err != nil {
		return err
	}
	fmt.Printf("已导入：%s → KYC %s，账户 %s（%s），银行账户 %d 个。用该邮箱登录（演示验证码 000000）即可。\n",
		in.Email, kycStatus, acctStatus, tail4(acct.AccountNo), map[bool]int{true: 1, false: 0}[in.BankID != ""])
	return nil
}

var refEncoding = base32.StdEncoding.WithPadding(base32.NoPadding)

func newRef(now time.Time) (string, error) {
	b := make([]byte, 3)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return "FX" + now.Format("060102") + "-" + refEncoding.EncodeToString(b), nil
}

// ---------- verify ----------

// dwGetter：verify 需要的 DW 能力（测试中替换为假实现）。
type dwGetter interface {
	Do(ctx context.Context, method, path string, reqBody, out any) error
}

func verify(ctx context.Context, cfg *config.Config, db *sql.DB, email, dwUser string, out io.Writer) error {
	if dwUser == "" {
		if strings.TrimSpace(email) == "" {
			return errors.New("需要 -email 或 -dw-user")
		}
		err := db.QueryRowContext(ctx, `
			SELECT d.dw_user_id FROM users_app u
			  JOIN applications a ON a.user_id = u.id AND a.deleted_at IS NULL
			  JOIN dw_users d ON d.application_id = a.id
			 WHERE lower(u.email) = lower($1) AND u.deleted_at IS NULL AND d.dw_user_id IS NOT NULL`, strings.TrimSpace(email)).Scan(&dwUser)
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("本地没有 %s 的 DW 用户关联", email)
		}
		if err != nil {
			return err
		}
	}
	if !cfg.DWConfigured() {
		return errors.New("需要 DW 凭据")
	}
	dw, err := dwclient.New(dwclient.Config{
		BaseURL: cfg.DW.BaseURL, AppKey: cfg.DW.AppKey, ClientID: cfg.DW.ClientID, ClientSecret: cfg.DW.ClientSecret,
		Timeout: cfg.DW.HTTPTimeout, TokenRequestsPerHour: cfg.DW.TokenRequestsPerHour, TokenRefreshSkew: cfg.DW.TokenRefreshSkew,
	})
	if err != nil {
		return err
	}
	return printVerify(ctx, dw, dwUser, out)
}

// printVerify 直接读取 DW 并打印编号与状态（不打印姓名等 PII）。
func printVerify(ctx context.Context, dw dwGetter, dwUser string, out io.Writer) error {
	fmt.Fprintf(out, "DW 沙盒原始数据（%s）\n", time.Now().UTC().Format(time.RFC3339))
	var u struct {
		ID     string `json:"id"`
		Status any    `json:"status"`
	}
	if err := dw.Do(ctx, "GET", "/users/"+dwUser, nil, &u); err != nil {
		return fmt.Errorf("GET /users/{id}：%w", err)
	}
	fmt.Fprintf(out, "  userID        %s\n  user.status   %s\n", u.ID, nameOf(u.Status))

	var kyc struct {
		Status any `json:"status"`
		KYC    *struct {
			Status any `json:"status"`
		} `json:"kyc"`
	}
	if err := dw.Do(ctx, "GET", "/users/"+dwUser+"/kyc-status", nil, &kyc); err != nil {
		return fmt.Errorf("GET kyc-status：%w", err)
	}
	k := nameOf(kyc.Status)
	if kyc.KYC != nil && nameOf(kyc.KYC.Status) != "" {
		k = nameOf(kyc.KYC.Status)
	}
	fmt.Fprintf(out, "  kyc.status    %s\n", k)

	var accts []dwAccount
	if err := dw.Do(ctx, "GET", "/users/"+dwUser+"/accounts", nil, &accts); err != nil {
		return fmt.Errorf("GET /users/{id}/accounts：%w", err)
	}
	if len(accts) == 0 {
		fmt.Fprintln(out, "  （无账户）")
	}
	for _, a := range accts {
		fmt.Fprintf(out, "  accountID     %s\n  accountNo     %s\n  account       %s · %s · opened %s\n",
			a.ID, a.AccountNo, nameOf(a.AccountType), nameOf(a.Status), a.Opened)
		var m struct {
			Updated string `json:"updated"`
			Cash    struct {
				CashBalance                json.Number `json:"cashBalance"`
				CashAvailableForTrade      json.Number `json:"cashAvailableForTrade"`
				CashAvailableForWithdrawal json.Number `json:"cashAvailableForWithdrawal"`
			} `json:"cash"`
		}
		if err := dw.Do(ctx, "GET", "/accounts/"+a.ID+"/summary/money", nil, &m); err != nil {
			fmt.Fprintf(out, "  money         读取失败：%v\n", err)
			continue
		}
		fmt.Fprintf(out, "  money         cash %s · buyingPower %s · withdrawable %s · updated %s\n",
			m.Cash.CashBalance, m.Cash.CashAvailableForTrade, m.Cash.CashAvailableForWithdrawal, m.Updated)
	}
	return nil
}
