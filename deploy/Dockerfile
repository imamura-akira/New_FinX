# FinX 后端镜像（沙盒演示部署用）。构建上下文：仓库中的 backend/ 目录。
#   docker build -f deploy/Dockerfile backend
# 多阶段构建：golang 编译静态二进制 → distroless 运行（含 CA 证书、非 root、无 shell）。
# 不包含任何凭据：运行时配置通过 env_file 注入（服务器上的 backend/.env，不进 git）。

FROM golang:1.27-alpine AS build
WORKDIR /src
ENV CGO_ENABLED=0 GOTOOLCHAIN=auto
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/server ./cmd/server \
 && go build -trimpath -ldflags "-s -w" -o /out/demoreset ./cmd/demoreset

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/server /app/server
COPY --from=build /out/demoreset /app/demoreset
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/server"]
