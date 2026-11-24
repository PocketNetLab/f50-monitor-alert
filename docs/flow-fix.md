# F50 v1.0.1 · 流量计数溢出修复 / Traffic Arithmetic Fix

## 证据 / Evidence

设备原始计数 / Raw counters:

- `monthly_rx_bytes=48496958175`
- `monthly_tx_bytes=266914486385`
- 正确合计 / Correct total: `315411444560` bytes
- 32-bit remainder: `315411444560 % 4294967296 = 1878831952`

这与 v1.0 的 `FLOW_V65_STATE` 完全一致，因此问题是旧版 Shell 算术溢出，而不是原生接口未读取成功。  
The exact equality proves a 32-bit arithmetic wraparound in the prior script.

## 修复 / Fix

- Use AWK math for all large byte sums, differences, and daily/monthly accumulators; valid byte integers remain exact under 2^53.
- Use `flow_v101.state`, `flow_history_v101.tsv`, `flow_v101.native`, `flow_v101.quality` and `flow_v101.since`.
- Preserve old `flow_v65.*` ledgers and all temperature/signal history; do not splice inaccurate old deltas into new totals.
- The first valid reading establishes a zero baseline. Send real data through the F50, then sample again to confirm increments.

## Testing

Local synthetic checks for source acquisition, 315GB native counter, 35MB updates and >4GB deltas passed. Not yet confirmed on every F50 firmware. This change does not switch mobile data or shut down devices.
