# 任务计划：创建 start-codex.sh 脚本

## 目标
参考 /Users/777java/777/soft/start-claude.sh，创建相似的 start-codex.sh 脚本，支持通过交互式菜单选择不同提供商启动 Codex CLI。

## 技术基础
- Codex CLI 使用 OpenAI 兼容 API
- 需要设置环境变量：`OPENAI_API_BASE` 和 `OPENAI_API_KEY`
- 代理服务器端点：`http://8.137.115.72:9014/v1`
- 认证通过服务器上的 OAuth 认证文件自动处理

## 执行步骤

### 步骤 1: 创建脚本框架
- 文件位置：`/Users/777java/777/soft/start-codex.sh`
- 添加颜色输出变量定义
- 添加配置关联数组 CONFIGS

### 步骤 2: 定义配置选项
预设配置项：
1. 自建CLIProxyAPI (远程) - http://8.137.115.72:9014
2. 自建CLIProxyAPI (本地) - http://localhost:9014
3. 自建gcli2api (远程) - http://8.137.115.72:9015/antigravity
4. 自建gcli2api (本地) - http://127.0.0.1:9015/antigravity
5. 本地Antigravity2Api - http://127.0.0.1:9013
6. 本地sub2api - http://localhost:9015

### 步骤 3: 实现核心函数
- `get_sorted_keys()` - 获取排序后的配置键
- `show_menu()` - 显示交互式菜单
- `start_codex()` - 启动 Codex 的核心函数
- `main()` - 主循环

### 步骤 4: 添加环境变量配置
- 设置 `OPENAI_API_BASE` 为选中的端点
- 设置 `OPENAI_API_KEY` 为占位符值（代理服务器会通过认证文件处理）
- 调用 `codex` 命令启动

### 步骤 5: 添加命令检查
- 检查 codex 命令是否可用

## 预期结果
用户运行脚本后可以看到交互式菜单，选择提供商后自动启动 Codex CLI 连接对应的代理服务器。