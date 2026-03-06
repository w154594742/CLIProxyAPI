#!/bin/bash
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 错误处理函数
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

info() {
    echo -e "${GREEN}$1${NC}"
}

# 检查 Go 环境
if ! command -v go &> /dev/null; then
    error_exit "Go is not installed. Please install Go 1.24 or later."
fi

# 检查 Go 版本
GO_VERSION=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
GO_MAJOR=$(echo $GO_VERSION | cut -d. -f1)
GO_MINOR=$(echo $GO_VERSION | cut -d. -f2)
if [[ $GO_MAJOR -lt 1 ]] || [[ $GO_MAJOR -eq 1 && $GO_MINOR -lt 24 ]]; then
    warning "Go version $GO_VERSION detected. Go 1.24+ is recommended."
fi

# 检查 Git 环境
if ! command -v git &> /dev/null; then
    warning "Git is not installed. Using default version information."
    USE_GIT=false
else
    USE_GIT=true
fi

# 自动检测上游版本号
detect_upstream_version() {
    # 1. 优先从 version.go 读取（如果存在）
    if [[ -f "internal/buildinfo/version.go" ]]; then
        local version=$(grep 'UpstreamVersion = ' internal/buildinfo/version.go 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
        if [[ -n "$version" && "$version" != "v0.0.0" ]]; then
            echo "$version"
            return
        fi
    fi

    # 2. 从 Git 历史自动检测
    if [[ "$USE_GIT" == "true" ]]; then
        local merge_commit=$(git log --grep="Merge origin/main" --format="%H" -1 2>/dev/null)
        if [[ -n "$merge_commit" ]]; then
            # 尝试从合并提交消息中提取版本号
            local version=$(git log ${merge_commit} --format="%s" -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [[ -n "$version" ]]; then
                echo "$version"
                return
            fi

            # 尝试从上游提交中提取
            local upstream_commit=$(git rev-parse ${merge_commit}^2 2>/dev/null)
            if [[ -n "$upstream_commit" ]]; then
                version=$(git log ${upstream_commit} --format="%s" -5 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return
                fi
            fi
        fi
    fi

    # 3. 使用默认版本
    echo "v6.0.0"
}

# 获取上游版本号
UPSTREAM_VERSION=$(detect_upstream_version)

# 验证版本号格式
if [[ ! "$UPSTREAM_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    warning "Upstream version format may be incorrect: ${UPSTREAM_VERSION}"
    warning "Expected format: vX.Y.Z (e.g., v6.8.44)"
fi

# 获取 Git 信息
if [[ "$USE_GIT" == "true" ]]; then
    COMMIT_HASH=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "unknown")
    COMMIT_FULL=$(git rev-parse HEAD 2>/dev/null || echo "none")

    # 检测 dirty 状态
    if [[ -n $(git status -s 2>/dev/null) ]]; then
        COMMIT_HASH="${COMMIT_HASH}-dirty"
        warning "Working directory has uncommitted changes"
    fi
else
    COMMIT_HASH="unknown"
    COMMIT_FULL="none"
fi

BUILD_DATE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# 构建参数
LDFLAGS="-X 'main.versionBase=${UPSTREAM_VERSION}' \
         -X 'main.commitHash=${COMMIT_HASH}' \
         -X 'main.commitFull=${COMMIT_FULL}' \
         -X 'main.buildDate=${BUILD_DATE}'"

# 输出构建信息
info "Building CLIProxyAPI..."
echo "  Upstream Version: ${UPSTREAM_VERSION}"
echo "  Commit Hash: ${COMMIT_HASH}"
echo "  Build Date: ${BUILD_DATE}"
echo ""

# 执行构建
if go build -ldflags="${LDFLAGS}" -o cli-proxy-api ./cmd/server/; then
    info "Build complete: ./cli-proxy-api"
    info "Version: ${UPSTREAM_VERSION}-wqp-dev-${COMMIT_HASH}"
else
    error_exit "Build failed"
fi
