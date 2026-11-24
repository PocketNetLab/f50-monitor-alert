# F50 Monitor & Alert · 中兴 F50 设备监控与微信警报

**版本：v1.0（首次公开发布）**　|　**项目仓库：[PocketNetLab/f50-monitor-alert](https://github.com/PocketNetLab/f50-monitor-alert)**

适用于 **ZTE F50 + UFI-TOOLS 完整版/高级后台** 的社区插件。通过网页监控温区、蜂窝流量增量和 RSRP/SINR（如固件提供），可选使用 PushPlus 发送温度报警及每日设备健康报告。非中兴或 UFI-TOOLS 官方产品。

## 核心功能

- 1h / 6h / 12h / 24h CPU/SoC 温度曲线，小时刻度、最高最低和阈值线。
- 每小时流量增量柱状图及日/月监测增量；原厂月度流量独立展示，**不是运营商账单**。
- 4G/5G RSRP 及有条件提供的 SINR 趋势。固件无法提供时显示不可用。
- 65/70/75℃ 三级可配置持续高温警报及快速升温提醒。
- PushPlus 微信测试、即时警报、每日 HTML 表格与三张 SVG 图表（**微信客户端是否展示 SVG 需实机验证**）。
- 一键温区识别、监控自检、历史 CSV 导出、运行日志和开机自启。
- **只监控和通知，不执行关机、重启、CPU 调频或移动数据开关。**

## 安装

1. 在 F50 的 UFI-TOOLS 「插件功能」中导入 `F50_Monitor_Alert_v1.0.txt`（不要导入 `src/` 中的文件）。
2. 点击提交并刷新 UFI-TOOLS 网页，打开右上角 **「F50 监控警报」**。
3. 点击 **「一键安装 / 从旧版升级」**。旧版数据保存在原目录；升级不删除流量和温度历史。
4. 点击「识别温区」，选择已与原后台读数核对的温区；不要把所有温区最高值当成 CPU 温度。
5. 如需微信推送，在 [PushPlus](https://www.pushplus.plus/) 获取 Token，选择启用并发送测试消息；确认微信实际收到后再开启日报。

## 升级和数据

- 与此前内部测试版使用同一个数据目录：`/data/local/tmp/f50_alert_v6`。升级时不应点击「卸载守护及数据」。
- 若先前内部测试版已经出现过统计基线重置，本版不会猜测或自动拼接过去不一致的数据。首次监测可能从 0 开始，连续采样后才累计。
- 今日/本月**监测增量**只表示有效采样之间的可确认变化，不与原厂「月度原始计数」相加。长时间漏采样不强行归入某一小时。
- `monitor.sh.previous` 是升级前脚本备份；**不包含账户 Token**。
- 原始图表数据不足24小时时，只显示已采样区间，不能补出不存在的历史。

## 兼容性与限制

已由使用者在 **ZTE F50、UFI-TOOLS v4.1.5/v4.1.6** 的实际环境中测试过部分温度、流量与 RSRP 读取流程；本次对外发布的 v1.0 仍需更多设备及长期运行验证。其他机型/固件均未验证。

- `goform`、`ufi_req`、`zreq` 等接口在不同固件上可能不同。
- 推送接口返回成功**不等于微信已送达**，也不保证微信客户端支持内嵌 SVG。
- 插件检测的是 F50 芯片温区，不是外置锂电池包的电芯温度，**不能代替电池保护电路**。
- 仅供 DIY/设备观察，不保证全天候告警必达。

## 使用帮助与反馈

[提交问题 / 联系维护者](https://github.com/PocketNetLab/f50-monitor-alert/issues) · [打开公开仓库](https://github.com/PocketNetLab/f50-monitor-alert)

- 仓库公开后，优先通过 **GitHub Issues** 反馈，附 UFI-TOOLS 版本、F50 固件版本、复现步骤、脱敏日志。
- [项目 Issues（联系维护者 / 反馈问题）](https://github.com/PocketNetLab/f50-monitor-alert/issues)；**请勿在 Issue 中公开 Token/设备登录凭据**。
- 隐私说明见 [docs/PRIVACY.md](docs/PRIVACY.md)，问题模板见 `.github/ISSUE_TEMPLATE/bug_report.md`。

## 开源与归属

MIT License。代码由维护者提出需求并在 AI 辅助下开发、测试与迭代；**UFI-TOOLS 是独立第三方开源项目**，本插件与官方无隶属或认证关系。