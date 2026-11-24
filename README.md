# F50 Monitor & Alert · F50 设备监控与微信警报

**v1.0 · Community Plugin for UFI-TOOLS**  
[中文说明](#中文介绍) · [English](#english-introduction) · [下载安装 / Download](#下载安装--installation) · [联系作者 / Contact](#作者与联系--author--contact)

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
| 三级温度提醒 | 可设定持续高温阈值及升温速度预警；**只提醒，不关机** |
| 蜂窝流量统计 | 当日/当月**监控增量**和每小时柱状图，另行展示可用的原厂月度计数 |
| 4G/5G 信号监测 | RSRP 趋势；SINR 仅在设备/固件提供有效值时显示 |
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
| Heat alerts | Configurable sustained-temperature thresholds and rapid-rise warning; **no auto-shutdown** |
| Mobile data usage | Daily/monthly **monitored deltas** and hourly bars; separate native counter when available |
| 4G/5G radio status | RSRP trends, optional SINR when exposed by the firmware |
| WeChat reports | PushPlus event notifications, daily HTML tables, and optional charts (SVG display depends on the client) |
| Diagnostics | Thermal-zone selection, data export, logs, self-check, and startup monitoring |

### Other use cases

- **Inside clothes or a jacket pocket:** Get notified when the hotspot heats up unexpectedly while continuously powered from a battery pack.
- **Inside a backpack:** Track temperature changes when the F50 is out of sight in a poorly ventilated compartment.
- **Trains, cars and commuting:** Compare radio signal quality, data traffic and thermal trends during mobility.
- **Desk, dorm or office operation:** Keep long-running usage records and receive daily summaries.
- **Cooling-fan experiments:** Compare temperature charts before and after changing airflow (the plugin does not control fans or battery power).

**Read-only policy:** No automatic power-off, reboot, mobile-data toggle, or CPU frequency changes. Data usage figures are device-side estimates, **not carrier billing records**.

## 下载安装 / Installation

**Plugin file:** [F50_Monitor_Alert_v1.0.txt](F50_Monitor_Alert_v1.0.txt)

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

## 兼容性与限制 / Compatibility & Limitations

- 已在部分 ZTE F50 + UFI-TOOLS v4.1.5/v4.1.6 环境中验证过温度、流量和 RSRP 功能；公开 v1.0 尚缺乏多设备、长期稳定性验证。  
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

## 作者与联系 / Author & Contact

**作者 / Maintainer:** **PocketNetLab**  
**GitHub:** https://github.com/PocketNetLab  
**项目主页 / Repository:** https://github.com/PocketNetLab/f50-monitor-alert  
**联系作者、功能建议或故障反馈 / Contact, feature requests & bug reports:**  
**https://github.com/PocketNetLab/f50-monitor-alert/issues**

欢迎提交兼容性反馈或改进建议，尽量附上 F50 固件、UFI-TOOLS 版本和**脱敏**后的诊断信息。  
Community feedback and contributions are welcome. Please include firmware and UFI-TOOLS versions plus **redacted** diagnostic information. Do not share personal tokens or credentials.
