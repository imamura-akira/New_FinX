// Package store 提供 PostgreSQL 连接与 schema 迁移（golang-migrate，迁移文件内嵌）。
package store

import (
	"context"
	"database/sql"
	"embed"
	"errors"
	"fmt"
	"time"

	"github.com/golang-migrate/migrate/v4"
	migratepgx "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	_ "github.com/jackc/pgx/v5/stdlib" // database/sql 驱动名 "pgx"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// ErrNoDatabaseURL：未配置 DATABASE_URL。
var ErrNoDatabaseURL = errors.New("store: 未配置 DATABASE_URL")

// Store 持有数据库连接池。
type Store struct {
	DB *sql.DB
}

// Open 建立连接池并 ping。错误信息不包含连接串（可能含口令）。
func Open(ctx context.Context, dsn string) (*Store, error) {
	if dsn == "" {
		return nil, ErrNoDatabaseURL
	}
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, errors.New("store: 打开数据库失败")
	}
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("store: 连接数据库失败: %w", sanitize(err))
	}
	return &Store{DB: db}, nil
}

// Ping 用于健康检查。
func (s *Store) Ping(ctx context.Context) error { return s.DB.PingContext(ctx) }

// Close 关闭连接池。
func (s *Store) Close() error { return s.DB.Close() }

// MigrateUp 执行全部未应用的迁移。
func (s *Store) MigrateUp() error {
	m, err := s.migrator()
	if err != nil {
		return err
	}
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("store: 迁移失败: %w", err)
	}
	return nil
}

// MigrateDown 回滚一步（开发用）。
func (s *Store) MigrateDown() error {
	m, err := s.migrator()
	if err != nil {
		return err
	}
	if err := m.Steps(-1); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("store: 回滚失败: %w", err)
	}
	return nil
}

func (s *Store) migrator() (*migrate.Migrate, error) {
	src, err := iofs.New(migrationsFS, "migrations")
	if err != nil {
		return nil, fmt.Errorf("store: 读取迁移文件失败: %w", err)
	}
	drv, err := migratepgx.WithInstance(s.DB, &migratepgx.Config{})
	if err != nil {
		return nil, fmt.Errorf("store: 初始化迁移驱动失败: %w", err)
	}
	return migrate.NewWithInstance("iofs", src, "pgx", drv)
}

// sanitize 只保留错误类型描述，避免把 DSN（可能含口令）带进日志。
func sanitize(err error) error {
	var ne interface{ Timeout() bool }
	if errors.As(err, &ne) && ne.Timeout() {
		return errors.New("连接超时")
	}
	return errors.New("无法连接（详情已省略，避免泄露连接串）")
}
