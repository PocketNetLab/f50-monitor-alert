# Changelog / 更新日志

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