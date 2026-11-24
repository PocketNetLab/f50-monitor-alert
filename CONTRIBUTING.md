# Contributing

欢迎通过 GitHub Issues 报告缺陷或提供复现实验。

- 优先报告可以复现的真实 F50 兼容性问题，不凭想象添加大量复杂功能。
- 修改 `src/monitor.sh` 后需同步重新编码到 `F50_Monitor_Alert_v1.0.txt` 中的 `PAYLOAD`，并更新 `EXPECTED` 字节长度。
- 提交前运行 `python3 tests/smoke.py`，并在真实设备上验证温度、流量、信号、PushPlus 推送和开机自启。
- 不要提交 Token、用户日志、移动设备标识或其他私密数据。