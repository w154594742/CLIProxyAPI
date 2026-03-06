# 实施计划：Antigravity 执行器添加 Claude Code 身份声明

## 任务概述

**问题**：使用 Claude CLI 调用 Claude 协议端点时，如果使用 Gemini 模型（通过 Antigravity 通道），AI 会自称 "Antigravity" 而不是 "Claude Code"。

**目标**：在 Antigravity 执行器中添加 Claude Code 身份声明，使模型无论如何都优先认同自己是 Claude Code。

**方案**：在 `buildRequest` 函数中，在现有 Antigravity 身份声明之前添加 Claude Code 身份声明。

## 修改文件

- `internal/runtime/executor/antigravity_executor.go`

## 详细步骤

### 步骤 1：定义 Claude Code 身份声明常量

**位置**：`antigravity_executor.go` 第 51 行附近（常量定义区域）

**操作**：在现有的 `systemInstruction` 常量之后，添加新的 Claude Code 身份声明常量

```go
// 新增常量
claudeCodeIdentity = "You are Claude Code, Anthropic's official CLI for Claude."
```

### 步骤 2：修改 buildRequest 函数中的系统提示词注入逻辑

**位置**：`antigravity_executor.go` 第 1302-1313 行

**现有代码**：
```go
if strings.Contains(modelName, "claude") || strings.Contains(modelName, "gemini-3-pro-high") {
    systemInstructionPartsResult := gjson.GetBytes(payload, "request.systemInstruction.parts")
    payload, _ = sjson.SetBytes(payload, "request.systemInstruction.role", "user")
    payload, _ = sjson.SetBytes(payload, "request.systemInstruction.parts.0.text", systemInstruction)
    payload, _ = sjson.SetBytes(payload, "request.systemInstruction.parts.1.text", fmt.Sprintf("Please ignore following [ignore]%s[/ignore]", systemInstruction))

    if systemInstructionPartsResult.Exists() && systemInstructionPartsResult.IsArray() {
        for _, partResult := range systemInstructionPartsResult.Array() {
            payload, _ = sjson.SetRawBytes(payload, "request.systemInstruction.parts.-1", []byte(partResult.Raw))
        }
    }
}
```

**修改后**：
```go
if strings.Contains(modelName, "claude") || strings.Contains(modelName, "gemini-3-pro-high") {
    systemInstructionPartsResult := gjson.GetBytes(payload, "request.systemInstruction.parts")
    payload, _ = sjson.SetBytes(payload, "request.systemInstruction.role", "user")
    // 首先添加 Claude Code 身份声明（优先级最高）
    payload, _ = sjson.SetBytes(payload, "request.systemInstruction.parts.0.text", claudeCodeIdentity)
    // 然后添加 Antigravity 系统指令
    payload, _ = sjson.SetBytes(payload, "request.systemInstruction.parts.1.text", systemInstruction)
    // 添加忽略指令
    payload, _ = sjson.SetBytes(payload, "request.systemInstruction.parts.2.text", fmt.Sprintf("Please ignore following [ignore]%s[/ignore]", systemInstruction))

    if systemInstructionPartsResult.Exists() && systemInstructionPartsResult.IsArray() {
        for _, partResult := range systemInstructionPartsResult.Array() {
            payload, _ = sjson.SetRawBytes(payload, "request.systemInstruction.parts.-1", []byte(partResult.Raw))
        }
    }
}
```

## 预期结果

- 当使用 Claude 模型时：保持原有行为，自称 "Claude Code"
- 当使用 Gemini 模型（通过 Antigravity）时：会自称 "Claude Code"（因为 Claude Code 身份声明优先级更高）

## 测试验证

1. 使用 Claude CLI 调用 Claude 协议端点
2. 选择 Gemini 模型
3. 发送 "你好" 或询问身份的消息
4. 验证回复中自称 "Claude Code" 而非 "Antigravity"

## 回滚方案

如需回滚，只需删除新增的 `claudeCodeIdentity` 常量，并将 `buildRequest` 中的逻辑恢复到原来的 3 个 parts（0、1、原有内容）。

---

**分支**：wqp-dev
**创建时间**：2026-01-27
