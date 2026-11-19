// Package api 内嵌 App ↔ 后端接口契约（openapi.yaml，依据 design/api-spec.md v1）。
package api

import _ "embed"

// OpenAPI 是 v1 契约原文。
//
//go:embed openapi.yaml
var OpenAPI []byte
