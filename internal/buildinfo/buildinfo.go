// Package buildinfo exposes compile-time metadata shared across the server.
package buildinfo

// The following variables are overridden via ldflags during release builds.
// Defaults cover local development builds.
var (
	// Version 完整版本号，格式：v{上游版本}-{分支后缀}-{提交哈希}
	// 构建时通过 ldflags 注入 versionBase 和 commitHash
	Version = ""

	// Commit 完整的 Git 提交哈希
	Commit = "none"

	// BuildDate 构建时间
	BuildDate = "unknown"

	// versionBase 基础版本，构建时注入
	versionBase = "dev"

	// commitHash 短提交哈希，构建时注入
	commitHash = "unknown"
)

// init 初始化完整版本号
func init() {
	if versionBase == "dev" {
		// 开发环境：使用默认值
		Version = UpstreamVersion + "-" + BranchSuffix + "-dev"
	} else {
		// 构建环境：组合完整版本
		Version = versionBase + "-" + BranchSuffix + "-" + commitHash
	}
}

// SetBuildInfo 设置构建信息（由 main 包在 init 时调用）
func SetBuildInfo(base, shortHash, fullHash, date string) {
	versionBase = base
	commitHash = shortHash
	Commit = fullHash
	BuildDate = date

	// 重新组合版本号
	if versionBase == "dev" {
		Version = UpstreamVersion + "-" + BranchSuffix + "-dev"
	} else {
		Version = versionBase + "-" + BranchSuffix + "-" + commitHash
	}
}
