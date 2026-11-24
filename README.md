# F50 Monitor & Alert · F50 设备监控与微信警报

**v2.0.1 · Community Plugin for UFI-TOOLS · 正式版 / Stable release**  
[中文说明](#中文介绍) · [English](#english-introduction) · [下载安装 / Download](#下载安装--installation) · [联系作者 / Contact](#作者与联系--author--contact)


## 中兴 UFI-TOOLS 适用机型 / Model compatibility

> **框架支持不等于插件已通过测试。** 本插件非 UFI-TOOLS 官方组件，以下“UFI-TOOLS 支持”依据的是上游文档或社区个案。

| 设备 | UFI-TOOLS 证据 | 本插件 v2.0.1 |
| --- | --- | --- |
| **中兴 F50（MU300）** | 上游主要适配设备 | **主要适配目标**；完整实机验收仍待完成 |
| **中兴 U30 Air** | 上游主要适配设备 | **待验证候选** |
| **中兴 V50** | 上游 User_Doc 列出 | **待验证候选** |
| **飞猫 U20（F50 固件形态）** | 上游有条件列出 | **条件候选，未验证** |
| **中兴 M3（部分固件）** | 上游有条件列出 | **条件候选，未验证** |
| **中兴 F50 Pro（MU3356）** | 社区 B28 / Android 15 / UFI-TOOLS v4.0.0 部署案例 | **实验性候选，未验证** |
| **中兴 U30 Pro** | 不等于 U30 Air | **未列入候选** |
| **中兴 U50 Pro / U60 Pro** | 上游维护者确认 ZWRT 的接口与 F50/U30 不同 | **不支持** |
| **其他中兴 Android 手机、平板** | 部分可运行 UFI-TOOLS | **不属于本插件目标范围** |

**所需 UFI-TOOLS：设备端 Full（完整版）+ 高级功能 / Root Shell。** 仅装在手机上的 PE 版不满足后台守护运行条件。原厂流量和 RSRP 接口为 F50 的 GoForm；温区编号依固件而定；LED 实现为 F50 的 `sc27xx` 路径。**其他机型不得启用实体温控灯，也不能默认原厂流量与 RSRP 可读。**

[详细机型矩阵、接口清单与验证步骤](docs/COMPATIBILITY.md) · [UFI-TOOLS 上游说明](https://github.com/kanoqwq/UFI-TOOLS) · [上游机型文档](https://github.com/kanoqwq/UFI-TOOLS/blob/http-server-version/User_Doc.md)

## v2.0.1 温度通知优化 / Quiet thermal alerts

**v2.0.1：升温速度（RISING）不再触发任何推送，旧排队的 RISING 通知也会丢弃。温度告警必须达到至少50℃，仍按三级持续高温设置触发（默认65/70/75℃）；弱信号预警与日报照常发送。**

**新安装默认 22:00 推送当日统计**（升级保留原时间和 PushPlus Token）。RSRP 连续五分钟 ≤ -105 dBm 才发弱信号提醒，信号连续三分钟 ≥ -100 dBm 才重新布防。提供温度、累计流量、RSRP 三条折线趋势；左侧纵轴固定，缺失采样不填充。

**安全与兼容性**：保留 v1.2.2 监控历史、流量计数基线与配置目录。LED 默认关闭，只有用户主动启用后才进行灯控。不会自动关机、切断移动数据或调节 CPU 频率。监控的是芯片温度而不是外接电池的电芯温度。微信内嵌 SVG 是否展示、PushPlus 能否实际送达、F50 驱动行为均需设备实测。

**安装 / Install**：设备页面若仍显示 v1.2.2，必须导入 v2.0.1 并执行「一键安装 / 从旧版升级」才能生效；更新 GitHub 代码不会自动修改 F50。下载仓库根目录 `F50_Monitor_Alert_v2.0.1.txt` 并导入 UFI-TOOLS，打开插件点击「一键安装 / 从旧版升级」，再运行「只读自检」并发送微信测试消息。

**English:** v2.0.1 disables rapid-rise push alerts, enforces a minimum 50°C for temperature alerts, and preserves sustained-heat, weak-signal, and daily reports. It also adds same-day reporting (22:00 on fresh installs), sustained weak-signal alerts and improved stale-data indication. Upgrades preserve stored settings and history. Physical-device verification remains necessary.

## 中文介绍

### 这是什么？

**F50 Monitor & Alert** 是专为 **装在外置充电背包、由移动电源持续供电的中兴 F50 随身 Wi-Fi** 使用场景而设计的监控插件。

**典型场景：F50 连接充电背包或外置移动电源后，被放进衣服口袋、外套内侧或书包夹层。** 设备可能因衣物遮挡、书包内部通风差、5G 高负载或弱信号而**突然升温**；用户却未必能及时看到机身状态。充电背包还可能持续给 F50 供电，即使软件关机也可能再次通电启动。因此本插件专注于 **持续监测温度、记录异常并及时向手机发送微信警报**，提醒用户检查摆放位置与散热，而不是自动关机或断网。

插件运行在 **ZTE F50 + UFI-TOOLS 高级后台**，可用浏览器查看设备状态，并通过 **PushPlus** 将摘要和异常提醒发送到微信。

> **重要安全说明：** 监测到的是 F50 的 SoC/芯片温区，并不是背包内锂电池电芯温度。本插件不能测量电芯温度、不能控制充电背包断电，也不能替代电池包的 BMS、NTC 温度保护或物理散热措施。

### 主要功能

| 功能 | 说明 |
| --- | --- |
| 温度监控 | 1h / 6h / 12h / 24h 曲线、整点时间轴、最高/最低/平均温度 |
| 三级温度提醒 | 仅持续高温阈值触发推送（最低50℃，默认65/70/75℃）；**已停用升温过快提醒，不关机** |
| 蜂窝流量统计 | 当日/当月**监控增量**与当天累计流量折线图，另行展示可用的原厂月度计数 |
| 4G/5G 信号监测 | RSRP 趋势（不显示不稳定的 SINR）；RSRP≤-105 dBm 连续 5 分钟推送弱信号提醒 |
| 微信 PushPlus | 即时异常摘要、每日 HTML 统计表、温度/流量/信号图表（微信内 SVG 显示依客户端支持） |
| 运维工具 | 温区识别、状态采样、日志查看、CSV 导出、监控自检、开机自启 |

**运行原则：** 只读取监控数据和发送通知，**不主动关机、不重启、不关闭移动数据、不调节 CPU 频率**。网络流量为设备侧估算，**不等于运营商计费流量**。

### 典型使用情景

- **衣服口袋或外套内：** F50 持续由充电背包供电，衣物覆盖后热量积聚，温度突然升高时自动发微信提醒
- **书包、通勤背包或夹层内：** 设备处于封闭空间，通风不足且用户难以摸到机身，借助手机监控温度走势
- **火车、汽车与移动途中：** 网络频繁切换、弱信号或持续传输时，联动查看 RSRP、流量与温度变化
- **宿舍、办公桌、长时间下载或共享网络：** 全天候记录设备发热与流量情况，定期收取健康日报
- **外接散热风扇测试：** 对比散热条件变化前后的 24h 温度曲线；插件不直接控制风扇或电池电源

## English Introduction

### What is it?

**F50 Monitor & Alert** is a community monitoring plugin designed primarily for the **ZTE F50 portable 5G hotspot used inside an external battery-powered carrying/charging pouch or backpack**, often alongside a cooling fan.

**Typical scenario:** An externally powered F50 is tucked **inside a jacket or clothing pocket, or into a backpack compartment**. Covered by fabric or surrounded by other items, it may experience a **sudden temperature rise** due to trapped heat, high 5G traffic, or weak cellular coverage—while the user cannot easily see or touch the device. A charging backpack may also keep supplying power, so a software shutdown may not keep the F50 off. The plugin therefore focuses on **continuous monitoring, temperature trend recording, and prompt WeChat alerts**, helping the user check ventilation and device placement instead of attempting shutdown or network interruption.

It runs with the **ZTE F50 UFI-TOOLS enhanced web interface** and optionally sends alerts and daily summaries through **PushPlus (WeChat)**.

> **Battery safety:** The displayed SoC/thermal-zone temperature is **not the temperature of the battery cells inside the pouch**. This software cannot disconnect external power or replace battery-management protections, thermal sensors, or adequate ventilation.

### Key Features

| Feature | Description |
| --- | --- |
| Temperature trends | 1h/6h/12h/24h charts with clock-time labels, min/max/average |
| Heat alerts | Sustained-heat alerts (minimum 50°C; default 65/70/75°C). Rapid-rise warnings disabled; **no auto-shutdown** |
| Mobile data usage | Daily/monthly **monitored deltas** and cumulative daily line chart; separate native counter when available |
| 4G/5G radio status | RSRP trends and weak-signal alerts (≤ -105 dBm for 5 min); unavailable SINR omitted |
| WeChat reports | PushPlus event notifications, daily HTML tables, and optional charts (SVG display depends on the client) |
| Diagnostics | Thermal-zone selection, data export, logs, self-check, and startup monitoring |

### Other use cases

- **Inside clothes or a jacket pocket:** Get notified when the hotspot heats up unexpectedly while continuously powered from a battery pack.
- **Inside a backpack:** Track temperature changes when the F50 is out of sight in a poorly ventilated compartment.
- **Trains, cars and commuting:** Compare radio signal quality, data traffic and thermal trends during mobility.
- **Desk, dorm or office operation:** Keep long-running usage records and receive daily summaries.
- **Cooling-fan experiments:** Compare temperature charts before and after changing airflow (the plugin does not control fans or battery power).

**Read-only policy:** No automatic power-off, reboot, mobile-data toggle, or CPU frequency changes. Data usage figures are device-side estimates, **not carrier billing records**.

## 可选温控指示灯 / Optional Thermal LED

- **低于55℃白灯 / White below 55°C**
- **达到55℃蓝灯 / Blue at or above 55°C**
- **达到65℃红灯 / Red at or above 65°C**

灯控独立开关，默认关闭；手动启用时使用已选、经过核实的 F50 CPU/SoC 温区，**不会自动关机、重启或断网**。降温回切采用 1℃ 回差以减少闪烁。如果旧版「U30 U20 F50 温控指示灯」仍在设备中，将拒绝启用以避免同时写入 LED。此功能需对应硬件 LED 节点及高级后台/root 权限，**目前尚未在更多 F50 固件上实机验证**。

The physical LED controller is **opt-in and disabled by default**. Below 55°C = white, 55–64.9°C = blue, 65°C or higher = red, with 1°C cooling hysteresis. Requires supported LED sysfs nodes and access to the verified SoC thermal zone. Conflicting legacy thermal LED scripts block activation. No power or mobile-data actions are performed. Hardware compatibility remains to be verified.

### v1.1.1 旧温控灯清理 / Legacy LED Cleanup

**中文：** 如果已经从 UFI-TOOLS 插件列表删除了旧版 `U30 U20 F50 温控指示灯`，新版仍提示冲突，通常是旧脚本 `/data/kano_temp_led.sh` 或开机启动项残留。升级至 **v1.1.1** 后，在温控指示灯区点击 **「清理旧温控灯残留（仅旧脚本）」**，确认后会仅停止该旧脚本、删除其文件及匹配的启动命令。该操作不会删除温度、流量、信号、PushPlus 配置或其他启动行；遇到不符合预期的自定义启动命令会拒绝删除。接着选择并保存非自动 CPU 温区，勾选 **「启用实体 LED 温控灯」** 再点击 **「应用开关」**。

**English:** After deleting the old thermal LED plugin entry, its background script or boot hook might remain. v1.1.1 adds an opt-in **“Clean up leftover thermal LED script”** action. It targets only the legacy file, its exact standalone boot command and matching script process; monitoring history and PushPlus settings are preserved. The script refuses ambiguous customized boot entries. Then select a verified CPU thermal zone, check the enable box and apply.

## 下载安装 / Installation

**Plugin file:** [F50_Monitor_Alert_v2.0.1.txt](F50_Monitor_Alert_v2.0.1.txt)

1. 在 F50 的 UFI-TOOLS「插件功能」中导入上述 TXT 文件，提交并刷新页面。  
   In UFI-TOOLS → Plugins, import the TXT file, submit, then refresh the web page.
2. 打开「F50 监控警报」，执行「一键安装 / 从旧版升级」。  
   Open F50 Monitor & Alert and choose the install/upgrade action.
3. 识别并校对 CPU/SoC 温区；不要将任意温区最高值直接当作 CPU 温度。  
   Identify and verify the SoC thermal zone against the device dashboard.
4. 可选：在 [PushPlus](https://www.pushplus.plus/) 获取 Token，保存在设备本地，发送测试通知并确认微信收到。  
   Optionally configure PushPlus and verify that WeChat actually receives a test notification.

**旧版本升级 / Upgrading:** 内部测试版本的数据目录保持为 `/data/local/tmp/f50_alert_v6` 以便兼容。不要点击「卸载守护及数据」以免清除历史。流量计数器重置或旧统计口径不一致时，监控增量可能需要重新从有效基线累计。  
Existing test builds use `/data/local/tmp/f50_alert_v6` for compatibility. Do not use “Uninstall daemon and data” when retaining history is important. Delta counters may restart from a new baseline after resets.

## v1.0.1 流量修复说明 / Traffic Counter Fix

**中文：** v1.0 采用 Shell 32 位整数运算，遇到 F50 大流量计数器时可能发生取余回绕，导致“今日/本月 0.00 MB”或统计异常。v1.0.1 使用可精确表示当前字节范围的 AWK 运算处理收发总量及累计增量，并把新统计放入 `flow_v101.*` 文件。原 `flow_v65.*` **不会被删除**；首次有效采样显示 0 MB 正常，后续有效采样和实际联网后才增长。

**English:** Version 1.0 could overflow 32-bit Shell arithmetic with large modem counters, leading to zero or incorrect traffic deltas. v1.0.1 uses safe AWK-based byte arithmetic and starts an independent `flow_v101.*` ledger while preserving previous files. A first-sample value of 0 MB is expected; subsequent increments should accumulate normally.

详见 / Details: [docs/flow-fix.md](docs/flow-fix.md)

## 兼容性与限制 / Compatibility & Limitations

- 已在部分 ZTE F50 + UFI-TOOLS v4.1.5/v4.1.6 环境中验证过温度、流量和 RSRP 功能；公开 v1.1.1 尚缺乏多设备、长期稳定性验证。  
  Some functionality has been exercised on ZTE F50 with UFI-TOOLS v4.1.5/v4.1.6; extensive multi-device and long-duration validation is still pending.
- `goform`、`ufi_req`、`zreq` 接口随固件可能变化。SINR 等参数可能缺失。  
  Firmware-dependent endpoints and radio measurements may be unavailable.
- PushPlus API 接收成功并不代表微信最终送达；客户端对 SVG 图片的支持可能不同。  
  A successful PushPlus API response does not guarantee WeChat delivery or embedded SVG rendering.
- 与 UFI-TOOLS 或中兴官方无隶属关系。Independent community project; not affiliated with ZTE or UFI-TOOLS.

## 隐私与开源 / Privacy & License

- **不要**在公开 Issues、截图或日志中上传 PushPlus Token、SIM/设备身份信息、账号密码或家庭网络配置。  
  **Never post** tokens, SIM/device identifiers, passwords, or private network details in public issues.
- 源码见 [src/](src/)；安全说明见 [SECURITY.md](SECURITY.md)，隐私说明见 [docs/PRIVACY.md](docs/PRIVACY.md)。
- MIT License；版权与维护者：**PocketNetLab**。

---

## 捐赠 / Donate

**中文**

- 如果这个项目对你有帮助，欢迎打赏支持维护
- 捐赠完全自愿，不影响功能使用
- 感谢每一位支持者

**English**

- Donations are optional and appreciated
- Your support helps ongoing maintenance and improvements
- Thank you for supporting this project

<div align="center">
<table>
  <tr>
    <th align="center">微信支付 / WeChat Pay</th>
    <th align="center">支付宝 / Alipay</th>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/wechat-pay.svg" alt="微信支付收款码 / WeChat Pay QR code" width="240"></td>
    <td align="center"><img src="docs/images/alipay-pay.svg" alt="支付宝收款码 / Alipay QR code" width="240"></td>
  </tr>
</table>
</div>

> 收款码仅用于自愿支持项目维护，插件及其功能免费使用。 / Donations are entirely optional. The plugin and all features remain free.

---

## 作者与联系 / Author & Contact

**作者 / Maintainer:** **PocketNetLab**  
**GitHub:** https://github.com/PocketNetLab  
**项目主页 / Repository:** https://github.com/PocketNetLab/f50-monitor-alert  
**联系作者、功能建议或故障反馈 / Contact, feature requests & bug reports:**  
**https://github.com/PocketNetLab/f50-monitor-alert/issues**

欢迎提交兼容性反馈或改进建议，尽量附上 F50 固件、UFI-TOOLS 版本和**脱敏**后的诊断信息。  
Community feedback and contributions are welcome. Please include firmware and UFI-TOOLS versions plus **redacted** diagnostic information. Do not share personal tokens or credentials.
