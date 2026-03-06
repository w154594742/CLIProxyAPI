# GitHub Actions Docker 构建任务

## 任务上下文

**需求：** 使用 GitHub Actions 通过 wqp-dev 分支推送 tag 构建 Docker 镜像，推送到 GitHub Container Registry，并在 docker-compose.yml 中使用

**技术栈：**
- Go 1.24+
- Docker + Buildx
- GitHub Actions
- GitHub Container Registry (ghcr.io)

**目标：**
1. 创建 GitHub Actions workflow
2. 支持多架构构建（amd64 + arm64）
3. 推送到 ghcr.io/w154594742/cliproxyapi
4. 更新 docker-compose.yml 使用新镜像

## 执行计划

### 步骤 1：创建 GitHub Actions 工作流
- 文件：`.github/workflows/docker-build.yml`
- 触发条件：wqp-dev 分支 tag 推送
- 权限：packages write

### 步骤 2：配置 Docker Buildx 和 QEMU
- 设置跨平台构建环境
- 启用构建缓存

### 步骤 3：配置 ghcr.io 认证
- 使用 GITHUB_TOKEN 自动认证
- Registry: ghcr.io

### 步骤 4：配置镜像元数据
- 自动生成标签（latest, 版本号, SHA）
- 语义化版本支持

### 步骤 5：多架构镜像构建
- 平台：linux/amd64, linux/arm64
- 构建参数：VERSION, COMMIT, BUILD_DATE
- 推送到 ghcr.io

### 步骤 6：更新 docker-compose.yml
- 修改镜像地址为 ghcr.io/w154594742/cliproxyapi
- 保持环境变量支持

### 步骤 7：添加文档说明
- 更新 README 使用说明

### 步骤 8：测试验证
- 创建测试 tag
- 验证构建流程

## 关键配置

**镜像地址：** ghcr.io/w154594742/cliproxyapi
**支持架构：** amd64, arm64
**标签策略：** latest, 版本号, SHA

## 风险控制

- 使用官方 Actions，稳定可靠
- 不影响现有代码
- 可随时回滚
