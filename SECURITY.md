# Security Policy

本插件需要 UFI-TOOLS 的 Root Shell 能力，**只在自己拥有或获授权管理的 F50 上安装**。

- 不上传私密 Token、设备账号、Cookie、IMEI、完整调试日志。
- PushPlus Token 保存在 F50 上；不要把设备数据目录加入 Git 仓库。
- 举报安全问题前，请通过项目维护者 GitHub Issues 联系（请勿公开敏感信息）；不要在公开 Issue 中放置敏感凭据。
- 脚本不会关闭网络或关机，但 Root 权限及第三方依赖仍有实际风险；发布前应验证守护自启与卸载路径。