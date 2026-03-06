# CLIProxyAPI 远程部署脚本

## 任务概述
编写一个 sh 脚本，实现以下功能：
1. 本地构建 Docker 镜像（linux/amd64 平台）
2. 导出并压缩镜像
3. 上传到阿里云服务器
4. 载入镜像
5. 滚动更新运行中的容器（cli-proxy-api、cli-proxy-api-2、cli-proxy-api-3、cli-proxy-api-4）
6. 支持回滚功能

## 服务器信息
- IP: 8.137.115.72
- 端口: 22
- 用户: root
- 项目路径: /opt/docker_projects/CLIProxyAPI*

## 容器命名规范
- cli-proxy-api
- cli-proxy-api-2
- cli-proxy-api-3
- cli-proxy-api-4

## 核心功能
- 自动检测运行中的容器
- 滚动更新（逐个容器更新）
- 保留原有端口映射和挂载配置
- 版本标签支持回滚

## 状态
- 创建时间: 2026-01-28
- 状态: 执行中
