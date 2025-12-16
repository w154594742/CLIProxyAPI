#!/bin/bash
# ============================================================================
# CLIProxyAPI 部署辅助脚本
# ============================================================================
# 作者: wangqiupei
# 用途: 帮助用户在服务器上快速部署 CLIProxyAPI
# 使用方法: ./deploy-helper.sh
# ============================================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[步骤]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          CLIProxyAPI 部署辅助脚本                            ║
║          作者: wangqiupei                                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo ""
}

# 检查依赖
check_dependencies() {
    print_step "检查系统依赖..."

    local missing_deps=()

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
        print_error "Docker 未安装"
    else
        print_success "Docker 已安装 ($(docker --version | cut -d' ' -f3 | tr -d ','))"
    fi

    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
        print_error "Docker Compose 未安装"
    else
        if command -v docker-compose &> /dev/null; then
            print_success "Docker Compose 已安装 ($(docker-compose --version | cut -d' ' -f3 | tr -d ','))"
        else
            print_success "Docker Compose (Plugin) 已安装"
        fi
    fi

    # 检查 unzip (可选)
    if ! command -v unzip &> /dev/null; then
        print_warning "unzip 未安装 (非必需)"
    fi

    # 如果有缺失的关键依赖,显示安装提示
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        print_error "缺少必要的依赖,请先安装:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        print_info "安装方法 (Ubuntu/Debian):"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y docker.io docker-compose"
        echo ""
        print_info "安装方法 (CentOS/RHEL):"
        echo "  sudo yum install -y docker docker-compose"
        echo ""
        exit 1
    fi

    echo ""
}

# 检查并初始化 .env 文件
setup_env_file() {
    print_step "配置环境变量..."

    if [ ! -f .env ]; then
        # 优先使用生产环境配置模板
        if [ -f .env.production.example ]; then
            print_info "未检测到 .env 文件,从生产环境配置模板创建..."
            cp .env.production.example .env
            print_success ".env 文件已创建 (基于生产环境模板)"
        elif [ -f .env.example ]; then
            print_info "未检测到 .env 文件,从示例配置创建..."
            cp .env.example .env
            print_success ".env 文件已创建"
        else
            print_error "配置模板文件不存在,无法创建默认配置"
            exit 1
        fi
    else
        print_success ".env 文件已存在"

        # 检查是否是新的解压部署包
        if [ -f VERSION_INFO.txt ]; then
            print_info "检测到版本信息文件,显示打包详情:"
            cat VERSION_INFO.txt
            print_info "================================"
        fi
    fi

    echo ""
    print_warning "=========================================="
    print_warning "重要: 请务必修改以下配置项"
    print_warning "=========================================="
    echo ""

    # 检查关键配置
    check_config_item "MANAGEMENT_SECRET_KEY" "管理员密码"

    echo ""
    read -p "是否现在编辑 .env 文件? (y/n) [y]: " edit_env
    edit_env=${edit_env:-y}

    if [[ "$edit_env" =~ ^[Yy]$ ]]; then
        # 尝试使用用户首选编辑器
        if [ -n "$EDITOR" ]; then
            $EDITOR .env
        elif command -v vim &> /dev/null; then
            vim .env
        elif command -v nano &> /dev/null; then
            nano .env
        elif command -v vi &> /dev/null; then
            vi .env
        else
            print_warning "未找到文本编辑器,请手动编辑 .env 文件"
            print_info "编辑命令: vi .env 或 nano .env"
            read -p "编辑完成后按回车继续..."
        fi
    else
        print_warning "请稍后手动编辑 .env 文件!"
        print_info "编辑命令: vi .env"
    fi

    echo ""
}

# 检查配置项是否为默认值
check_config_item() {
    local key=$1
    local desc=$2
    local default_values=("change-me-to-a-strong-password" "PLEASE-CHANGE-THIS-TO-A-STRONG-PASSWORD" "")

    if [ -f .env ]; then
        local value=$(grep "^${key}=" .env 2>/dev/null | cut -d'=' -f2-)
        value=$(echo "$value" | tr -d ' "'"'"'')  # 移除空格和引号

        for default in "${default_values[@]}"; do
            if [ "$value" = "$default" ]; then
                print_error "${desc} (${key}) 仍为默认值,请修改!"
                return 1
            fi
        done

        if [ -z "$value" ]; then
            print_warning "${desc} (${key}) 为空,建议设置"
            return 1
        fi

        print_success "${desc} (${key}) 已配置"
        return 0
    fi

    return 1
}

# 检查必要的目录和文件
check_required_files() {
    print_step "检查必要文件..."

    local required_files=("docker-compose.yml")
    local missing_files=()

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
            print_error "缺少文件: $file"
        else
            print_success "文件存在: $file"
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "缺少必要文件,请确认部署包完整性"
        exit 1
    fi

    # 检查可选文件
    if [ ! -f "config.yaml" ] && [ ! -f "config.example.yaml" ]; then
        print_warning "未找到配置文件,将使用默认配置"
    fi

    # 创建必要的目录
    print_info "创建必要目录..."
    mkdir -p auths logs
    print_success "目录结构已就绪"

    echo ""
}

# 拉取 Docker 镜像
pull_docker_image() {
    print_step "拉取 Docker 镜像..."

    read -p "是否现在拉取最新镜像? (y/n) [y]: " pull_image
    pull_image=${pull_image:-y}

    if [[ "$pull_image" =~ ^[Yy]$ ]]; then
        if docker-compose pull 2>/dev/null || docker compose pull 2>/dev/null; then
            print_success "Docker 镜像拉取成功"
        else
            print_warning "镜像拉取失败,将在启动时自动拉取"
        fi
    else
        print_info "跳过镜像拉取,将使用本地镜像或在启动时拉取"
    fi

    echo ""
}

# 启动服务
start_service() {
    print_step "启动 CLIProxyAPI 服务..."

    echo ""
    read -p "确认启动服务? (y/n) [y]: " confirm_start
    confirm_start=${confirm_start:-y}

    if [[ ! "$confirm_start" =~ ^[Yy]$ ]]; then
        print_info "已取消启动,您可以稍后手动启动:"
        echo "  docker-compose up -d"
        exit 0
    fi

    # 尝试使用 docker-compose 或 docker compose
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    if [ $? -eq 0 ]; then
        print_success "服务启动成功!"
    else
        print_error "服务启动失败,请检查日志"
        exit 1
    fi

    echo ""
}

# 等待服务健康检查
wait_for_health() {
    print_step "等待服务健康检查..."

    local max_wait=60  # 最多等待 60 秒
    local waited=0
    local interval=3

    while [ $waited -lt $max_wait ]; do
        sleep $interval
        waited=$((waited + interval))

        # 检查容器状态
        if command -v docker-compose &> /dev/null; then
            container_status=$(docker-compose ps -q cli-proxy-api 2>/dev/null | xargs docker inspect -f '{{.State.Health.Status}}' 2>/dev/null)
        else
            container_status=$(docker compose ps -q cli-proxy-api 2>/dev/null | xargs docker inspect -f '{{.State.Health.Status}}' 2>/dev/null)
        fi

        if [ "$container_status" = "healthy" ]; then
            print_success "服务健康检查通过!"
            return 0
        fi

        echo -n "."
    done

    echo ""
    print_warning "健康检查超时,但服务可能正在启动中"
    print_info "您可以手动检查容器状态:"
    echo "  docker-compose ps"
    echo "  docker-compose logs"

    return 1
}

# 显示服务信息
show_service_info() {
    print_step "服务信息"
    echo ""

    # 读取端口配置
    local port=$(grep "^SERVER_PORT=" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' "'"'"'')
    port=${port:-8317}

    # 获取服务器 IP
    local server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    server_ip=${server_ip:-localhost}

    cat << EOF
╔═══════════════════════════════════════════════════════════════╗
║                    部署成功!                                  ║
╚═══════════════════════════════════════════════════════════════╝

服务地址:
  - 本地访问: http://localhost:${port}
  - 远程访问: http://${server_ip}:${port}
  - 健康检查: http://localhost:${port}/health

常用命令:
  查看服务状态:  docker-compose ps
  查看日志:      docker-compose logs -f
  重启服务:      docker-compose restart
  停止服务:      docker-compose stop
  启动服务:      docker-compose start
  完全删除:      docker-compose down

配置修改:
  1. 编辑 .env 文件: vi .env
  2. 重启服务: docker-compose restart

管理员密码修改:
  1. 编辑 .env 文件中的 MANAGEMENT_SECRET_KEY
  2. 重启服务: docker-compose restart

文档地址:
  - 项目文档: https://help.router-for.me/cn/
  - GitHub: https://github.com/router-for-me/CLIProxyAPI

EOF

    print_success "部署完成!"
}

# 主流程
main() {
    show_welcome
    check_dependencies
    check_required_files
    setup_env_file
    pull_docker_image
    start_service
    wait_for_health
    show_service_info
}

# 执行主流程
main
