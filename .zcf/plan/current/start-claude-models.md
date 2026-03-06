# 任务计划：扩展 start-claude.sh 支持三个模型配置

## 目标
修改 /Users/777java/777/soft/start-claude.sh，支持在配置中设置三个模型（opus/sonnet/haiku），分别设置对应的环境变量。

## 需求
- 配置格式扩展为：`名称|URL|Token|opus模型|sonnet模型|haiku模型`
- 第一个模型（opus）用作 `--model` 参数
- 设置三个环境变量：
  - `ANTHROPIC_DEFAULT_OPUS_MODEL`
  - `ANTHROPIC_DEFAULT_SONNET_MODEL`
  - `ANTHROPIC_DEFAULT_HAIKU_MODEL`
- 向前兼容：只配置1个模型时保持原有行为

## 执行步骤

### 步骤 1: 修改配置数组格式
- 将 CONFIGS 数组的格式从 4 段改为 6 段
- 暂时使用现有模型作为opus模型，为sonnet和haiku设置默认值

### 步骤 2: 修改 show_menu() 函数
- 解析 6 段配置
- 显示三个模型信息

### 步骤 3: 修改 start_claude() 函数
- 解析 6 段配置
- 设置三个环境变量
- 第一个模型用于 --model 参数

### 步骤 4: 测试验证
- 确保菜单显示正确
- 确保环境变量正确设置

## 预期结果
- 用户选择配置后，启动 Claude 时会设置三个环境变量
- 菜单显示三个模型信息