# Validation / 测试范围

## 已做 / Completed
- Syntax checks for the plugin JavaScript and embedded Android Shell script.
- Synthetic traffic-counter boundary tests and browser UI rendering tests in development.
- Selected ZTE F50 + UFI-TOOLS 4.1.5/4.1.6 telemetry observations from the primary tester.

## 尚未完成 / Pending
- Independent F50 devices and firmware combinations.
- Long-duration service uptime and restart behavior.
- Verified PushPlus SVG chart rendering on multiple WeChat clients.
- Charging backpack battery temperature protection (not supported; requires external hardware).

No guarantee of always-on delivery or battery safety. / 不保证告警必达或外接电池安全。

## v2.0.0 — 2026-11-24

- Locally checked JS and shell syntax, embedded Base64 decoding and exact payload length.
- Simulated sustained weak signal detection, recovery hysteresis, and missing RSRP.
- Physical verification pending: F50 installation / boot, radio counter behavior, LED physical outputs, PushPlus receipt, and WeChat SVG rendering.
- Do not disclose PushPlus tokens or unique device identifiers in Issues.
