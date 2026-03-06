// Package buildinfo exposes compile-time metadata shared across the server.
package buildinfo

// UpstreamVersion 记录已合并的上游版本号
// 每次从 origin/main 合并代码时，可以手动更新此版本号
// 如果不手动维护，构建脚本会自动从 Git 历史检测
const UpstreamVersion = "v6.0.0"

// BranchSuffix 当前开发分支后缀
const BranchSuffix = "wqp-dev"
