# Changelog / 更新日志

## v2.0.0 — 2026-11-24 (stable edition)

- Document device compatibility with source-backed tiers; add expandable guidance to the UI. UFI-TOOLS framework support is explicitly not proof of plugin compatibility.


- Upgrade the user-supplied v1.2.2 UFI-TOOLS plugin to 2.0.0 with backward-compatible state paths.
- Preserve cumulative daily traffic and fixed-axis temperature/RSRP charts; omit unavailable SINR.
- Add a PushPlus weak-signal warning for RSRP ≤ -105 dBm sustained five minutes, re-armed after ≥ -100 dBm for three minutes.
- Default fresh installs to **22:00 same-day** reports, preserving saved schedule and token on upgrade.
- Prevent stale-sample warning from being overwritten and isolate concurrent PushPlus JSON request files.
- JavaScript and Shell syntax, embedded Base64 integrity, and mock threshold tests passed locally. Real F50 / WeChat validation remains outstanding.


## v1.1.1 — 2026-11-24 (maintenance)

- Add a user-confirmed, one-click cleanup for the old `/data/kano_temp_led.sh` script and its exact UFI-TOOLS boot hook.
- Stop only the matching old script process, back up the previous boot file and refuse unexpected/custom boot commands.
- Preserve existing monitoring history, cellular traffic counters, signal logs and PushPlus settings.
- Keep LED control opt-in, with white below 55°C, blue from 55°C and red from 65°C; one-degree cooling hysteresis.
- Local shell/JS syntax and mocked cleanup tests passed. F50 device behavior needs user confirmation.


## v1.1.0 — 2026-11-24 (optional physical LED)

- Add an **optional and default-off** thermal LED switch to the UFI-TOOLS dashboard.
- **Below 55°C: white; 55–64.9°C: blue; at or above 65°C: red.**
- Apply 1°C cooldown hysteresis: red to blue below 64°C, blue to white below 54°C.
- Verify the selected CPU thermal zone before enabling; check F50 RGB LED sysfs support.
- Block activation when the legacy U30/U20/F50 thermal LED plugin is detected.
- On disable, attempt to restore the observed LED brightness.
- Preserve existing temperature, traffic, signal and WeChat PushPlus monitoring; no shutdown/network-control behavior.
- LED control currently has source-level and simulated checks, **not a verified real-device compatibility claim**.


## v1.0.1 — 2026-11-24 (bugfix)

- Fix 32-bit Android Shell wraparound in large native flow counters (31x GB can become 1.88 GB).
- Use AWK-safe arithmetic for combined RX+TX, deltas, daily/monthly totals and cellular fallback.
- Start a separate `flow_v101.*` ledger; preserve older flow files, temperature and signal histories, settings, and PushPlus token.
- Keep read-only policy: no shutdown, reboot, or mobile data changes.
- Synthetic flow tests passed, including large counter and >4GB deltas. F50 long-duration field verification is pending.


## v1.0 — 2026-11-24（首次公开发布）

- 发布适配 ZTE F50 / UFI-TOOLS 的只读设备监控插件。
- 温度：1/6/12/24小时曲线、整点时间轴、三级可配置高温提醒与采样时效提示。
- 流量：今日和本月监测增量、24小时小时柱状图、独立原厂月度计数与计数器重置处理。
- 信号：RSRP 与固件支持时的 SINR 趋势，缺失值不作填补。
- 推送：PushPlus 微信高温通知、每日统计表及可尝试显示的 SVG 趋势图。
- 开放日志、CSV 导出、温区识别和运行自检。
- 不包含自动关机、重启、关闭移动数据或修改 CPU 频率等控制命令。

> 此版本首次对外发布。开发期间的内部测试号不作为公开发布历史；部分设备兼容性和微信 SVG 展示能力仍需社区反馈验证。