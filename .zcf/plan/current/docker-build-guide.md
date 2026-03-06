# GitHub Actions Docker 构建使用指南

## 概述

本项目已配置 GitHub Actions 自动构建多架构 Docker 镜像（amd64 + arm64），并推送到 GitHub Container Registry。

## 触发构建

### 方式 1：推送 Tag（推荐）

在 `wqp-dev` 分支创建并推送 tag：

```bash
# 确保在 wqp-dev 分支
git checkout wqp-dev

# 创建 tag（使用语义化版本）
git tag v1.0.0

# 推送 tag 到远程
git push origin v1.0.0
```

### 方式 2：推送到 wqp-dev 分支

直接推送代码到 `wqp-dev` 分支也会触发构建：

```bash
git push origin wqp-dev
```

## 镜像标签

构建完成后，镜像会被推送到 `ghcr.io/w154594742/cliproxyapi`，包含以下标签：

- `latest` - 最新构建（wqp-dev 分支或 tag）
- `wqp-dev` - wqp-dev 分支最新构建
- `v1.0.0` - 完整版本号（仅 tag 触发）
- `v1.0` - 主次版本（仅 tag 触发）
- `v1` - 主版本（仅 tag 触发）
- `sha-abc1234` - commit SHA

## 使用镜像

### 使用 docker-compose

```bash
# 使用默认镜像（latest）
docker-compose up -d

# 使用特定版本
CLI_PROXY_IMAGE=ghcr.io/w154594742/cliproxyapi:v1.0.0 docker-compose up -d
```

### 直接使用 docker run

```bash
docker run -d \
  -p 9011:9011 \
  -v $(pwd)/config.yaml:/CLIProxyAPI/config.yaml \
  -v $(pwd)/auths:/root/.cli-proxy-api \
  ghcr.io/w154594742/cliproxyapi:latest
```

## 查看构建状态

1. 访问 GitHub 仓库的 Actions 页面
2. 查看 "Build and Push Docker Image" workflow
3. 点击具体的运行记录查看详细日志

## 镜像可见性设置

首次推送后，镜像默认为私有。如需公开访问：

1. 访问 https://github.com/w154594742?tab=packages
2. 找到 `cliproxyapi` 包
3. 点击 "Package settings"
4. 在 "Danger Zone" 中选择 "Change visibility"
5. 设置为 "Public"

## 多架构支持

镜像支持以下架构：
- `linux/amd64` - x86_64 服务器和 PC
- `linux/arm64` - ARM 服务器和 Apple Silicon Mac

Docker 会自动选择匹配当前系统的架构。

## 构建时间

- 首次构建：约 10-15 分钟
- 后续构建（有缓存）：约 5-8 分钟

## 故障排查

### 构建失败

1. 检查 Actions 日志中的错误信息
2. 确认 Dockerfile 语法正确
3. 确认 go.mod 依赖可下载

### 推送失败

1. 确认 GitHub Token 权限正确（workflow 已配置）
2. 检查网络连接

### 镜像拉取失败

1. 确认镜像已设置为公开（或已登录）
2. 检查镜像名称和标签是否正确
3. 使用 `docker pull ghcr.io/w154594742/cliproxyapi:latest` 测试

## 本地测试构建

在推送前可以本地测试多架构构建：

```bash
# 创建 buildx builder
docker buildx create --use

# 构建多架构镜像（不推送）
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VERSION=test \
  --build-arg COMMIT=$(git rev-parse HEAD) \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  -t ghcr.io/w154594742/cliproxyapi:test \
  .
```
