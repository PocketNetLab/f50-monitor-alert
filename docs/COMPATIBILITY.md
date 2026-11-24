# F50 Monitor & Alert v2.0.0 · UFI-TOOLS Compatibility

调查日期：2026-11-24。**UFI-TOOLS 框架的适配列表并非本插件的实机验证列表。** 本项目不是 UFI-TOOLS 官方组件；除 F50 作为主要开发目标外，所有其他型号都必须单独验证。F50 v2.0.0 也仍需要完整端到端设备验收。

## 型号与证据等级

| 设备型号 | UFI-TOOLS 上游或社区证据 | 插件状态 | LED |
| --- | --- | --- | --- |
| 中兴 **F50 / MU300** | 上游核心设备，测试固件含 `MU300_ZYV1.0.0B09` | **主要适配目标**，v2.0.0 实机验收待完成 | 仅为 F50 设计的可选功能，默认关闭 |
| 中兴 **U30 Air** | 上游核心设备，测试固件含 `U30Air_SSVB14` | **待验证候选** | 不启用 |
| 中兴 **V50** | 上游 User_Doc 列出 | **待验证候选** | 不启用 |
| 飞猫 **U20（F50 固件形态）** | 上游有条件列出，并非所有 U20 | **条件候选 / 未验证** | 不启用 |
| 中兴 **M3（部分固件）** | 上游有条件列出 | **条件候选 / 未验证** | 不启用 |
| 中兴 **F50 Pro / MU3356** | 第三方社区曾在 Android 15、B28 上部署 UFI-TOOLS v4.0.0 | **实验性候选 / 插件未验证** | 不启用 |
| 中兴 **U30 Pro** | 与 U30 Air 不同，缺少插件适用证据 | **未列入候选** | 不启用 |
| 中兴 **U50 Pro / U60 Pro** | 上游维护者称其基于 ZWRT，Web API 与 F50/U30 不同 | **当前不支持** | 不启用 |
| 中兴畅行60、远航60、W200DS 等手机 / 平板 | 某些型号可安装 UFI-TOOLS | **不属于本插件目标范围** | 不启用 |

## UFI-TOOLS 版本和运行条件

- **部署形态**：在设备本机安装 UFI-TOOLS **Full / 完整版**，要求“高级功能”与 **Root Shell / `runShellWithRoot`** 可用。手机上使用的 **Pocket Edition（PE）** 只提供远程管理，并不等同于设备本机运行监测守护。
- **后台守护**：需要 Android Shell、可写 `/data/local/tmp` 和可控制的开机自启脚本 `/sdcard/ufi_tools_boot.sh`；不同 UFI-TOOLS / 固件版本须确认这些条件。
- **CPU/SoC 温度**：从 `/sys/class/thermal/thermal_zone*/temp` 读取。不同机型的 thermal zone `type` / 编号不一定相同，必须避免把电池或充电温度误当成 SoC 温度。
- **RSRP / 蜂窝流量**：使用 F50 的 `goform_get_cmd_process` 与 `Z5g_rsrp`、`lte_rsrp`、`monthly_rx_bytes`、`monthly_tx_bytes` 等字段。优先查找 UFI-TOOLS 的 `/data/data/com.minikano.f50_sms/files/ufi_req`、`zreq`。跨机型缺失字段时应显示“不可用”，不能捏造数值。
- **LED**：当前按 F50 的 `/sys/class/leds/sc27xx:red/brightness`、`sc27xx:green/brightness`、`sc27xx:blue/brightness` 设计。其他型号即使恰有类似文件也不能认为灯控逻辑安全，**必须保持关闭**。
- **PushPlus / 日报**：需网络可达且 Token 在设备本机保存。接口接收不代表微信必达；内嵌 SVG 是否显示取决于微信客户端。

## 安全验证步骤

1. 用只读命令 `getprop ro.product.model` 和 `getprop ro.build.display.id` 确认型号与固件，记录 UFI-TOOLS 版本及 Root 情况。
2. 验证设备本机 Root Shell；检查 `/sys/class/thermal/thermal_zone*/type`，确认 CPU/SoC 温区。**非 F50 不测试灯控**。
3. 在可恢复测试环境中运行插件的“只读自检”和“诊断信号/流量接口”，确认温度、原厂蜂窝计数与 RSRP 是否为有效采样。
4. 验证长期采样、计数器重置、开机自启与 PushPlus 实际接收。任何步骤失败都应记录为该机型的已知限制，不应宣称全面支持。
5. 若反馈到 GitHub Issues，只提交设备型号、固件、UFI-TOOLS 版本和脱敏信息。不要上传 PushPlus Token、IMEI、SIM 标识或登录凭据。

## 来源

- 上游项目：[kanoqwq/UFI-TOOLS](https://github.com/kanoqwq/UFI-TOOLS)（F50/U30 Air、测试固件）
- 上游设备文档：[User_Doc.md §1.3](https://github.com/kanoqwq/UFI-TOOLS/blob/http-server-version/User_Doc.md)（V50、U20/F50 固件、M3 部分固件）
- 上游维护者解释：[Issue #37](https://github.com/kanoqwq/UFI-TOOLS/issues/37)（U50 Pro、U60 Pro 的 ZWRT / API 差异）
- **第三方社区单机测试，不是本插件适配证明**：[F50 Pro B28 Root + UFI-TOOLS](https://github.com/againrivers/zte-f50pro-b28-root)

本矩阵不提供跨硬件的刷机、Root 或分区操作指导；相关风险与插件兼容性是两个独立问题。
