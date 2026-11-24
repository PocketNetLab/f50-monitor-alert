#!/usr/bin/env python3
"""Offline v1.0.1 flow ledger regression: no F50 or network required."""
import json, os, pathlib, re, subprocess, tempfile
src=(pathlib.Path(__file__).resolve().parents[1]/"src/monitor.sh").read_text()
with tempfile.TemporaryDirectory() as tmp:
    src=src.replace("BASE=/data/local/tmp/f50_alert_v6","BASE="+tmp)
    src=re.sub(r"goform_fetch\(\) \{.*?\n\}\njson_number\(\)",
               'goform_fetch() { cat "$BASE/mock.json"; }\njson_number()',src,count=1,flags=re.S)
    src=src.replace("nowday=$(date +%Y%m%d);nowmon=$(date +%Y%m);nowts=$(date +%s)",
                    "nowday=$FAKE_DAY;nowmon=$FAKE_MON;nowts=$FAKE_TS")
    cut=src.rfind('\ncase "$1" in\n')
    assert cut>0,"Shell dispatcher not found"
    script=pathlib.Path(tmp)/"fixture.sh"
    script.write_text(src[:cut]+'\nflow_update\ncat "$FLOW"\ncat "$FLOWQUALITY"\n')
    def run(day,ts,rx,tx):
        (pathlib.Path(tmp)/"mock.json").write_text(json.dumps({
            "monthly_rx_bytes":str(rx),"monthly_tx_bytes":str(tx)}))
        out=subprocess.run(["sh",str(script)],check=True,capture_output=True,text=True,
            env={**os.environ,"FAKE_DAY":day,"FAKE_MON":day[:6],"FAKE_TS":str(ts)})
        rows=out.stdout.strip().splitlines()
        state=rows[-2].split()
        return int(state[3]),int(state[4]),int(state[5]),rows[-1]
    rx,tx=48496958175,266914486385
    assert (rx+tx)%(2**32)==1878831952
    assert run("20261124",100000,rx,tx)==(rx+tx,0,0,"BASELINE")
    assert run("20261124",100060,rx+5000000,tx+30000000)==(rx+tx+35000000,35000000,35000000,"OK")
    assert run("20261124",100120,rx+1505000000,tx+4030000000)==(rx+tx+5535000000,5535000000,5535000000,"OK")
    assert run("20261124",100180,rx+2405000000,tx+6130000000)==(rx+tx+8535000000,8535000000,8535000000,"OK")
    assert run("20261125",100240,rx+2406000000,tx+6131000000)==(rx+tx+8537000000,0,8535000000,"DAY_BOUNDARY")
    assert run("20261125",100300,100,200)==(300,0,8535000000,"COUNTER_RESET")
print("PASS: large native F50 byte counters, >4GB deltas, day boundary, counter reset")
