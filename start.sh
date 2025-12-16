#!/bin/bash

# CLIProxyAPI 开发模式启动脚本
# 作者: wangqiupei

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config.yaml"
CONFIG_EXAMPLE="${PROJECT_ROOT}/config.example.yaml"
ENV_FILE="${PROJECT_ROOT}/.env"
ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"
AUTH_DIR="${HOME}/.cli-proxy-api"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印标题
print_banner() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║     CLIProxyAPI 开发模式启动器        ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查 Go 环境
check_go() {
    log_info "检查 Go 环境..."
    if ! command -v go &> /dev/null; then
        log_error "Go 未安装！请先安装 Go 1.24 或更高版本"
        exit 1
    fi

    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    log_success "Go 版本: ${GO_VERSION}"
}

# 检查并创建配置文件
check_config() {
    log_info "检查配置文件..."

    # 检查并复制 config.yaml
    if [ ! -f "${CONFIG_FILE}" ]; then
        if [ -f "${CONFIG_EXAMPLE}" ]; then
            log_warning "config.yaml 不存在，从 config.example.yaml 复制..."
            cp "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
            log_success "配置文件已创建: ${CONFIG_FILE}"
            log_warning "请根据需要修改配置文件后再启动！"

            # 修改默认配置为开发模式
            if command -v sed &> /dev/null; then
                # 启用 debug 模式
                sed -i.bak 's/^debug: false/debug: true/' "${CONFIG_FILE}" 2>/dev/null || true
                # 设置默认 API Key
                sed -i.bak 's/your-api-key-1/sk-dev-local-key-123456/' "${CONFIG_FILE}" 2>/dev/null || true
                rm -f "${CONFIG_FILE}.bak"
                log_info "已自动启用 debug 模式并设置默认 API Key: sk-dev-local-key-123456"
            fi
        else
            log_error "配置文件不存在: ${CONFIG_FILE}"
            log_error "示例配置文件也不存在: ${CONFIG_EXAMPLE}"
            exit 1
        fi
    else
        log_success "配置文件已存在: ${CONFIG_FILE}"
    fi

    # 检查并复制 .env
    if [ ! -f "${ENV_FILE}" ]; then
        if [ -f "${ENV_EXAMPLE}" ]; then
            log_info "创建 .env 文件..."
            cp "${ENV_EXAMPLE}" "${ENV_FILE}"
            log_success ".env 文件已创建（可选配置）"
        fi
    fi
}

# 检查认证目录
check_auth_dir() {
    log_info "检查认证目录..."
    if [ ! -d "${AUTH_DIR}" ]; then
        log_warning "认证目录不存在，创建中..."
        mkdir -p "${AUTH_DIR}"
        log_success "认证目录已创建: ${AUTH_DIR}"
    else
        log_success "认证目录: ${AUTH_DIR}"

        # 检查是否有认证文件
        AUTH_FILES=$(find "${AUTH_DIR}" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
        if [ "${AUTH_FILES}" -gt 0 ]; then
            log_info "找到 ${AUTH_FILES} 个认证文件"
        else
            log_warning "未找到 OAuth 认证文件"
            log_warning "你可能需要先运行登录命令："
            echo -e "  ${YELLOW}./cli-proxy-api -claude-login${NC}  # Claude 登录"
            echo -e "  ${YELLOW}./cli-proxy-api -codex-login${NC}   # OpenAI 登录"
            echo -e "  ${YELLOW}./cli-proxy-api -login${NC}         # Gemini 登录"
        fi
    fi
}

# 下载依赖
download_deps() {
    log_info "检查 Go 模块依赖..."
    if [ ! -d "${PROJECT_ROOT}/vendor" ] && [ ! -f "${PROJECT_ROOT}/go.sum" ]; then
        log_info "首次运行，下载依赖中..."
        go mod download
        log_success "依赖下载完成"
    else
        log_success "依赖已就绪"
    fi
}

# 检查端口占用
check_port_availability() {
    local port=$1

    log_info "检查端口 ${port} 是否可用..."

    # 检查端口是否被占用
    if command -v lsof &> /dev/null; then
        # macOS/Linux 使用 lsof
        local pid=$(lsof -ti :${port} 2>/dev/null)

        if [ -n "${pid}" ]; then
            # 端口被占用，获取进程信息
            local process_info=$(ps -p ${pid} -o comm= 2>/dev/null || echo "未知进程")

            echo ""
            log_warning "端口 ${port} 已被占用！"
            echo -e "${YELLOW}进程 PID:${NC} ${pid}"
            echo -e "${YELLOW}进程名称:${NC} ${process_info}"
            echo ""

            # 询问用户是否要终止进程
            read -p "$(echo -e ${YELLOW}是否要强制终止该进程? [y/N]: ${NC})" -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "正在终止进程 ${pid}..."
                if kill -9 ${pid} 2>/dev/null; then
                    log_success "进程已终止"
                    sleep 1  # 等待端口释放

                    # 再次检查端口是否已释放
                    if lsof -ti :${port} &> /dev/null; then
                        log_error "端口 ${port} 仍被占用，请手动处理"
                        exit 1
                    else
                        log_success "端口 ${port} 已释放"
                    fi
                else
                    log_error "无法终止进程 ${pid}，可能需要 sudo 权限"
                    log_error "请手动执行: sudo kill -9 ${pid}"
                    exit 1
                fi
            else
                log_error "用户取消操作，退出启动"
                exit 1
            fi
        else
            log_success "端口 ${port} 可用"
        fi
    elif command -v netstat &> /dev/null; then
        # 备用方案：使用 netstat
        if netstat -an | grep -q "[:.]${port}.*LISTEN"; then
            log_warning "端口 ${port} 已被占用"
            log_warning "请手动检查并终止占用端口的进程"
            log_warning "使用命令: lsof -i :${port} 或 netstat -anp | grep ${port}"

            read -p "$(echo -e ${YELLOW}是否继续启动? [y/N]: ${NC})" -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "用户取消操作，退出启动"
                exit 1
            fi
        else
            log_success "端口 ${port} 可用"
        fi
    else
        log_warning "无法检查端口占用状态（lsof 和 netstat 均不可用）"
    fi
}

# 启动服务
start_service() {
    log_info "启动开发服务器..."
    log_info "工作目录: ${PROJECT_ROOT}"
    log_info "配置文件: ${CONFIG_FILE}"

    # 读取配置中的端口（简单解析）
    PORT=$(grep "^port:" "${CONFIG_FILE}" | awk '{print $2}' || echo "8317")
    HOST=$(grep "^host:" "${CONFIG_FILE}" | awk '{print $2}' || echo "")

    if [ -z "${HOST}" ] || [ "${HOST}" = '""' ]; then
        HOST="0.0.0.0"
    fi

    # 检查端口占用情况
    check_port_availability "${PORT}"

    echo ""
    log_success "服务即将启动..."
    log_success "监听地址: http://${HOST}:${PORT}"
    log_success "API 端点: http://localhost:${PORT}/v1/chat/completions"
    log_success "管理面板: http://localhost:${PORT}/v0/management"
    echo ""
    log_info "按 Ctrl+C 停止服务"
    echo ""

    # 使用 go run 启动（开发模式）
    cd "${PROJECT_ROOT}"
    exec go run ./cmd/server/
}

# 清理函数
cleanup() {
    log_info "正在停止服务..."
}

# 注册清理函数
trap cleanup EXIT INT TERM

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  --login                 仅执行 Gemini 登录（不启动服务）"
    echo "  --claude-login          仅执行 Claude 登录（不启动服务）"
    echo "  --codex-login           仅执行 OpenAI Codex 登录（不启动服务）"
    echo "  --qwen-login            仅执行 Qwen 登录（不启动服务）"
    echo "  --iflow-login           仅执行 iFlow 登录（不启动服务）"
    echo "  --build                 编译二进制文件（不启动）"
    echo "  --clean                 清理编译产物和缓存"
    echo ""
    echo "示例:"
    echo "  $0                      # 启动开发服务器"
    echo "  $0 --claude-login       # 执行 Claude OAuth 登录"
    echo "  $0 --build              # 编译二进制文件"
}

# 编译二进制
build_binary() {
    log_info "编译二进制文件..."
    cd "${PROJECT_ROOT}"

    VERSION="dev"
    COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    go build -ldflags="-X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" \
        -o cli-proxy-api ./cmd/server/

    log_success "编译完成: ${PROJECT_ROOT}/cli-proxy-api"
    log_info "运行: ./cli-proxy-api"
}

# 清理函数
clean_project() {
    log_info "清理项目..."
    cd "${PROJECT_ROOT}"

    # 清理编译产物
    if [ -f "cli-proxy-api" ]; then
        rm -f cli-proxy-api
        log_success "已删除: cli-proxy-api"
    fi

    # 清理测试缓存
    go clean -testcache
    log_success "已清理测试缓存"

    log_success "清理完成"
}

# OAuth 登录函数
do_login() {
    local login_flag=$1
    local login_name=$2

    log_info "执行 ${login_name} OAuth 登录..."
    cd "${PROJECT_ROOT}"
    go run ./cmd/server/ "${login_flag}"
}

# 主函数
main() {
    print_banner

    # 解析参数
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        --login)
            check_go
            check_config
            do_login "-login" "Gemini"
            exit 0
            ;;
        --claude-login)
            check_go
            check_config
            do_login "-claude-login" "Claude"
            exit 0
            ;;
        --codex-login)
            check_go
            check_config
            do_login "-codex-login" "OpenAI Codex"
            exit 0
            ;;
        --qwen-login)
            check_go
            check_config
            do_login "-qwen-login" "Qwen"
            exit 0
            ;;
        --iflow-login)
            check_go
            check_config
            do_login "-iflow-login" "iFlow"
            exit 0
            ;;
        --build)
            check_go
            build_binary
            exit 0
            ;;
        --clean)
            clean_project
            exit 0
            ;;
        "")
            # 默认：启动开发服务器
            check_go
            check_config
            check_auth_dir
            download_deps
            start_service
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
