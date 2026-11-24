# Privacy & Security / 隐私与安全

## 中文

F50 Monitor & Alert 在 F50 设备本地读取 SoC 温区、流量计数、移动网络信号以及运行状态。插件可在启用时通过 PushPlus 接口把温度警报和日报发送至指定微信。**不开启 PushPlus 时不应主动进行推送。**

PushPlus Token 是私密凭据：不要上传到公开 GitHub、Issues、截图或日志。发送到 PushPlus 的通知可能包含设备温度、流量和信号统计，第三方通知服务会处理该内容；请自行阅读 PushPlus 服务条款和隐私政策。

本插件不测量充电背包电芯温度，也无法断开外接电池供电。用于参考与观察，不能代替硬件安全防护。

## English

This plugin reads local F50 thermal-zone, cellular usage counter, radio signal, and runtime data. When configured and enabled, PushPlus transmits alerts and reports to a WeChat destination. Do not publish PushPlus tokens or device credentials.

Alerts may include device temperature, traffic, and signal data processed by the third-party PushPlus service. Review that service's privacy terms. The plugin does not monitor external battery-cell temperature or disconnect external power, and does not replace battery safety hardware.
