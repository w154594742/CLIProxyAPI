#!/bin/bash
# ============================================================================
# CLIProxyAPI 部署打包脚本
# ============================================================================
# 作者: wangqiupei
# 用途: 将项目打包为 zip 文件,用于服务器部署
# 使用方法: ./scripts/package-for-deploy.sh [选项]
# ============================================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示使用帮助
show_help() {
    cat << EOF
CLIProxyAPI 部署打包脚本

用途: 将项目打包为 zip 文件,便于服务器部署

使用方法:
  $0 [选项]

选项:
  -h, --help              显示此帮助信息
  -v, --version VERSION   指定版本号 (默认: 从 git tag 获取)
  -p, --platform PLATFORM 指定目标平台 (默认: linux/amd64)
                          可选值: linux/amd64, linux/arm64, darwin/amd64, darwin/arm64
  -o, --output DIR        指定输出目录 (默认: ./dist)
  --no-build              跳过编译步骤,仅打包现有文件
  --docker-only           仅打包 Docker Compose 部署文件

示例:
  $0                                    # 使用默认配置打包
  $0 -v v1.2.3 -p linux/amd64          # 指定版本和平台
  $0 --docker-only                      # 仅打包 Docker 部署文件
  $0 --no-build -o /tmp/package        # 跳过编译,输出到指定目录

打包内容:
  - 编译好的二进制文件 (可选)
  - docker-compose.yml
  - config.yaml (示例配置)
  - .env.production.example (生产环境配置模板)
  - 部署辅助脚本
  - README.md 和部署文档

EOF
}

# 默认配置
VERSION=""
PLATFORM="linux/amd64"
OUTPUT_DIR="./dist"
NO_BUILD=false
DOCKER_ONLY=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --no-build)
            NO_BUILD=true
            shift
            ;;
        --docker-only)
            DOCKER_ONLY=true
            shift
            ;;
        *)
            print_error "未知选项: $1"
            echo "使用 -h 或 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 自动获取版本号
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --always 2>/dev/null || echo "dev")
    print_info "自动检测版本号: $VERSION"
fi

# 解析平台参数
IFS='/' read -r GOOS GOARCH <<< "$PLATFORM"

print_info "=========================================="
print_info "CLIProxyAPI 打包配置"
print_info "=========================================="
print_info "版本号: $VERSION"
print_info "目标平台: $PLATFORM (GOOS=$GOOS, GOARCH=$GOARCH)"
print_info "输出目录: $OUTPUT_DIR"
print_info "跳过编译: $NO_BUILD"
print_info "仅 Docker: $DOCKER_ONLY"
print_info "=========================================="

# 固定的打包名称
PACKAGE_NAME="CLIProxyAPI"
PACKAGE_DIR="${OUTPUT_DIR}/${PACKAGE_NAME}"
print_info "创建打包目录: $PACKAGE_DIR"

# 清理之前的打包文件
print_info "清理之前的打包文件..."
if [ -d "$PACKAGE_DIR" ]; then
    print_info "删除旧的打包目录: $PACKAGE_DIR"
    rm -rf "$PACKAGE_DIR"
fi
if [ -f "${OUTPUT_DIR}/${PACKAGE_NAME}.zip" ]; then
    print_info "删除旧的压缩包: ${OUTPUT_DIR}/${PACKAGE_NAME}.zip"
    rm -f "${OUTPUT_DIR}/${PACKAGE_NAME}.zip"
fi

mkdir -p "$PACKAGE_DIR"

# 编译二进制文件 (如果需要)
if [ "$DOCKER_ONLY" = false ] && [ "$NO_BUILD" = false ]; then
    print_info "开始编译 Go 二进制文件..."
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    BUILD_DATE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

    BINARY_NAME="cli-proxy-api"
    if [ "$GOOS" = "windows" ]; then
        BINARY_NAME="cli-proxy-api.exe"
    fi

    CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" go build \
        -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" \
        -o "${PACKAGE_DIR}/${BINARY_NAME}" \
        ./cmd/server/

    print_success "二进制文件编译完成: ${BINARY_NAME}"

    # 显示文件大小
    FILE_SIZE=$(du -h "${PACKAGE_DIR}/${BINARY_NAME}" | cut -f1)
    print_info "文件大小: $FILE_SIZE"
fi

# 复制配置文件
print_info "复制配置文件..."
cp config.yaml "${PACKAGE_DIR}/config.example.yaml"
cp .env.example "${PACKAGE_DIR}/.env.example"

# 复制生产环境配置模板并重命名为 .env (方便首次部署)
if [ -f .env.production.example ]; then
    cp .env.production.example "${PACKAGE_DIR}/.env"
    print_info "已复制生产环境配置模板为 .env"
else
    cp .env.example "${PACKAGE_DIR}/.env"
    print_warning ".env.production.example 不存在,使用 .env.example 替代"
fi

# 复制 Docker Compose 配置
print_info "复制 Docker Compose 配置..."
cp docker-compose.yml "${PACKAGE_DIR}/"
cp Dockerfile "${PACKAGE_DIR}/"

# 复制部署脚本
print_info "复制部署脚本..."
if [ -f scripts/deploy-helper.sh ]; then
    cp scripts/deploy-helper.sh "${PACKAGE_DIR}/"
    chmod +x "${PACKAGE_DIR}/deploy-helper.sh"
else
    print_warning "deploy-helper.sh 不存在,跳过"
fi

# 复制文档
print_info "复制文档..."
cp README.md "${PACKAGE_DIR}/" 2>/dev/null || print_warning "README.md 不存在"

if [ -f docs/DEPLOYMENT.md ]; then
    mkdir -p "${PACKAGE_DIR}/docs"
    cp docs/DEPLOYMENT.md "${PACKAGE_DIR}/docs/"
else
    print_warning "docs/DEPLOYMENT.md 不存在,跳过"
fi

# 创建必要的目录结构
print_info "创建目录结构..."
mkdir -p "${PACKAGE_DIR}/auths"
mkdir -p "${PACKAGE_DIR}/logs"

# 创建简单的 README
print_info "生成部署说明..."
cat > "${PACKAGE_DIR}/DEPLOY_README.txt" << 'EOF'
# CLIProxyAPI 部署说明

## 快速开始

### 1. 配置环境变量
编辑 .env 文件,至少修改以下配置:
- MANAGEMENT_SECRET_KEY: 设置强密码

### 2. 启动服务

#### 使用 Docker Compose (推荐)
docker-compose up -d

#### 使用二进制文件
./cli-proxy-api

### 3. 验证服务
curl http://localhost:8317/health

## 配置说明

详细配置说明请参考:
- .env.example: 环境变量说明
- config.example.yaml: 配置文件示例
- docs/DEPLOYMENT.md: 完整部署文档

## 管理员密码修改

1. 编辑 .env 文件
2. 修改 MANAGEMENT_SECRET_KEY 值
3. 重启服务: docker-compose restart

## 技术支持

项目地址: https://github.com/router-for-me/CLIProxyAPI
文档地址: https://help.router-for.me/cn/
EOF

# 创建 zip 压缩包
print_info "创建 zip 压缩包..."
cd "$OUTPUT_DIR"
ZIP_FILE="${PACKAGE_NAME}.zip"
zip -r "$ZIP_FILE" "$PACKAGE_NAME" > /dev/null
cd - > /dev/null

# 创建版本信息文件 (可选)
VERSION_FILE="${PACKAGE_DIR}/VERSION_INFO.txt"
cat > "$VERSION_FILE" << EOF
CLIProxyAPI 打包信息
==================
文件名: ${ZIP_FILE}
打包时间: $(date)
版本号: ${VERSION}
Git 提交: ${COMMIT}
构建时间: ${BUILD_DATE}
目标平台: ${PLATFORM}

注意: 这个压缩包的文件名固定为 CLIProxyAPI.zip
      每次打包前会自动清理之前的文件
EOF

# 重新压缩以包含版本信息
cd "$OUTPUT_DIR"
zip -u "$ZIP_FILE" "$PACKAGE_NAME/VERSION_INFO.txt" > /dev/null 2>&1
cd - > /dev/null

# 显示打包结果
print_success "=========================================="
print_success "打包完成!"
print_success "=========================================="
print_success "压缩包位置: ${OUTPUT_DIR}/${ZIP_FILE}"
ZIP_SIZE=$(du -h "${OUTPUT_DIR}/${ZIP_FILE}" | cut -f1)
print_success "文件大小: $ZIP_SIZE"
print_success ""
print_info "🔧 部署步骤:"
print_info "1. 上传 ${ZIP_FILE} 到服务器"
print_info "   scp ${OUTPUT_DIR}/${ZIP_FILE} user@server:/opt/"
print_info ""
print_info "2. 解压覆盖现有文件"
print_info "   cd /opt && unzip -o ${ZIP_FILE}"
print_info ""
print_info "3. 进入目录并配置"
print_info "   cd CLIProxyAPI"
print_info "   vim .env  # 必须修改 MANAGEMENT_SECRET_KEY"
print_info ""
print_info "4. 启动服务"
print_info "   docker-compose up -d"
print_info "   或执行辅助脚本: ./deploy-helper.sh"
print_success ""
print_info "📌 重要说明:"
print_info "  - 压缩包固定名称: CLIProxyAPI.zip"
print_info "  - 每次打包会自动清理旧文件"
print_info "  - 解压时会覆盖现有文件 (使用 -o 参数)"
print_success "=========================================="

# 列出打包内容
print_info ""
print_info "📦 打包内容列表:"
ls -lh "$PACKAGE_DIR" | tail -n +2 | awk '{printf "  - %-30s %5s\n", $9, $5}'
