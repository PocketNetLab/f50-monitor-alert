#!/system/bin/sh
# F50 UFI-TOOLS v1.1.1: monitoring, PushPlus and OPTIONAL thermal LED. Never control power, radio or connectivity.
BASE=/data/local/tmp/f50_alert_v6
BIN=$BASE/monitor.sh
PID=$BASE/monitor.pid
CFG=$BASE/thresholds
ZONE=$BASE/zone
TOKEN=$BASE/push.token
PUSH=$BASE/push.on
DAILY=$BASE/daily.on
HOUR=$BASE/daily.hour
RISE=$BASE/rise.milli_per_min
LED_ON=$BASE/led.on
LED_SNAPSHOT=$BASE/led.original
LED_LAST=$BASE/led.last
LED_RED=/sys/class/leds/sc27xx:red/brightness
LED_WHITE=/sys/class/leds/sc27xx:green/brightness
LED_BLUE=/sys/class/leds/sc27xx:blue/brightness
LED_BRIGHT=96
LOG=$BASE/events.log
REC=$BASE/live
HISTORY=$BASE/temperature.tsv
SIGNAL=$BASE/signal.tsv
# Flow v1.0.1: preserve all older flow files, whose counters could overflow at 2^32.
# A new baseline avoids a false 300+ GB jump when migrating to safe arithmetic.
# Temperature, signal, settings and PushPlus configuration remain unchanged.
FLOWHIST=$BASE/flow_history_v101.tsv
STATS=$BASE/today.stats
YDAY=$BASE/yesterday.stats
FLOW=$BASE/flow_v101.state
FLOWRAW=$BASE/flow_v101.native
FLOWSINCE=$BASE/flow_v101.since
FLOWQUALITY=$BASE/flow_v101.quality
QUEUE=$BASE/push.queue
PUSH_SENT=$BASE/push.sent
REPORT_MARK=$BASE/report.queued
BOOT=/sdcard/ufi_tools_boot.sh
INTERVAL=10
CURL=/data/data/com.minikano.f50_sms/files/curl
[ -x "$CURL" ] || CURL=curl
mkdir -p "$BASE" || exit 1
[ -r "$CFG" ] || echo '65000 600 70000 180 75000 60' > "$CFG"
[ -r "$ZONE" ] || echo auto > "$ZONE"
[ -r "$PUSH" ] || echo 0 > "$PUSH"
[ -r "$DAILY" ] || echo 1 > "$DAILY"
[ -r "$HOUR" ] || echo 08 > "$HOUR"
[ -r "$RISE" ] || echo 1000 > "$RISE"
[ -r "$LED_ON" ] || echo 0 > "$LED_ON"  # Default OFF; never alter hardware without consent
chmod 700 "$BASE" 2>/dev/null || true

is_int() { case "$1" in ''|*[!0-9]*) return 1;; esac; return 0; }
# Android 32-bit /system/bin/sh may wrap $((rx+tx)) at 2^32.
# AWK arithmetic is floating-point with exact integer results for byte counters
# up to 2^53 (9 PB); all F50 sampled byte values are well within this limit.
bytes_add() {
  awk -v a="$1" -v b="$2" 'BEGIN { if(a<0||b<0||a+b>9007199254740991) exit 1; printf "%.0f\n",a+b }'
}
bytes_sub() {
  awk -v a="$1" -v b="$2" 'BEGIN { if(a<b||a<0||b<0) exit 1; printf "%.0f\n",a-b }'
}
bytes_lt() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a<b) }'; }

logit() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; n=$(wc -l < "$LOG" 2>/dev/null); [ "${n:-0}" -le 300 ] || { tail -n 240 "$LOG" > "$BASE/log.tmp" && mv "$BASE/log.tmp" "$LOG"; }; }
valid_zone() { case "$1" in auto) return 0;; thermal_zone[0-9]*) idx=${1#thermal_zone};is_int "$idx" && [ -r "/sys/class/thermal/$1/temp" ];; *) return 1;; esac; }
normalize() {
  raw=$1;is_int "$raw" || return 1
  if [ "$raw" -ge 15000 ] && [ "$raw" -le 105000 ];then value=$raw
  elif [ "$raw" -ge 15 ] && [ "$raw" -le 105 ];then value=$((raw*1000))
  elif [ "$raw" -gt 105 ] && [ "$raw" -le 1050 ];then value=$((raw*100))
  else return 1;fi
  printf '%s\n' "$value"
}
# Optional physical tri-color F50 LED: <55C white, 55-64.9C blue, >=65C red.
# Controlled ONLY when the user explicitly enables it. 1C falling hysteresis
# avoids switching rapidly near thresholds. Never modify modem/power settings.
led_supported() {
  [ -w "$LED_RED" ] && [ -w "$LED_WHITE" ] && [ -w "$LED_BLUE" ]
}
led_legacy_conflict() {
  # The third-party kano_temp_led.sh (v1.4) writes these same LED files.
  # Do not stop/delete other plugins without user consent.
  { [ -e /data/kano_temp_led.sh ] || [ -L /data/kano_temp_led.sh ]; } && return 0
  if [ -r "$BOOT" ] && grep -Fq 'kano_temp_led.sh' "$BOOT";then return 0;fi
  return 1
}
# Strictly match argv to avoid killing unrelated processes or grep/shell commands.
legacy_led_pids() {
  for p in /proc/[0-9]*;do
    [ -r "$p/cmdline" ] || continue
    if tr '\000' '\n' < "$p/cmdline" 2>/dev/null | grep -Fxq '/data/kano_temp_led.sh';then
      echo "${p##*/}"
    fi
  done
}
led_cleanup_legacy() {
  # Opt-in maintenance only: no traffic, temperature, modem, or PushPlus data touched.
  [ ! -L /data/kano_temp_led.sh ] || { echo LED_LEGACY_SYMLINK_REFUSED;return 1; }
  if [ -e "$BOOT" ];then
    [ -f "$BOOT" ] && [ -r "$BOOT" ] && [ -w "$BOOT" ] || { echo LED_BOOT_NOT_WRITABLE;return 1; }
    # Only the standalone command installed by the historical third-party plugin may be removed.
    awk 'index($0,"kano_temp_led.sh") && $0 !~ /^[[:space:]]*sh[[:space:]]+\/data\/kano_temp_led[.]sh[[:space:]]*&?[[:space:]]*$/ {bad=1} END{exit bad?1:0}' "$BOOT" ||
      { echo LED_BOOT_CUSTOM_LINE_REFUSED;return 1; }
  fi
  echo 0 > "$LED_ON"
  led_restore
  pids=$(legacy_led_pids)
  for oldpid in $pids;do
    case "$oldpid" in ''|*[!0-9]*) continue;;esac
    [ "$oldpid" = "$" ] && continue
    kill "$oldpid" 2>/dev/null || true
  done
  [ -z "$pids" ] || sleep 1
  still=$(legacy_led_pids)
  [ -z "$still" ] || { echo LED_LEGACY_PROCESS_STILL_RUNNING;return 1; }
  if [ -r "$BOOT" ] && grep -Fq 'kano_temp_led.sh' "$BOOT";then
    backup="$BASE/ufi_tools_boot_before_led_cleanup.bak"
    if [ ! -e "$backup" ];then
      cp "$BOOT" "$backup" && chmod 600 "$backup" || { echo LED_BOOT_BACKUP_FAILED;return 1; }
    fi
    newboot="${BOOT}.f50-led-tmp.$"
    awk '$0 !~ /^[[:space:]]*sh[[:space:]]+\/data\/kano_temp_led[.]sh[[:space:]]*&?[[:space:]]*$/' "$BOOT" > "$newboot" ||
      { rm -f "$newboot";echo LED_BOOT_EDIT_FAILED;return 1; }
    mv "$newboot" "$BOOT" || { rm -f "$newboot";echo LED_BOOT_REPLACE_FAILED;return 1; }
  fi
  if [ -f /data/kano_temp_led.sh ];then
    rm -f /data/kano_temp_led.sh || { echo LED_LEGACY_FILE_DELETE_FAILED;return 1; }
  fi
  led_legacy_conflict && { echo LED_LEGACY_REMAINS;return 1; }
  logit 'LED_LEGACY_CLEANED only old LED script and boot entry, all monitoring data preserved'
  echo LED_LEGACY_CLEANED
}
led_snapshot() {
  [ -r "$LED_SNAPSHOT" ] && return 0
  r=$(cat "$LED_RED" 2>/dev/null);w=$(cat "$LED_WHITE" 2>/dev/null);b=$(cat "$LED_BLUE" 2>/dev/null)
  for v in "$r" "$w" "$b";do is_int "$v" && [ "$v" -le 255 ] || return 1;done
  printf '%s %s %s\n' "$r" "$w" "$b" > "$LED_SNAPSHOT"
}
led_write() {
  printf '%s\n' "$1" > "$LED_RED" && printf '%s\n' "$2" > "$LED_WHITE" && printf '%s\n' "$3" > "$LED_BLUE"
}
led_restore() {
  # Restore the observed LED state; it may be superseded by normal firmware control.
  if [ -r "$LED_SNAPSHOT" ] && led_supported;then
    read -r r w b < "$LED_SNAPSHOT"
    led_write "$r" "$w" "$b" >/dev/null 2>&1 || true
  fi
  rm -f "$LED_SNAPSHOT" "$LED_LAST"
}
led_apply() {
  [ "$(cat "$LED_ON" 2>/dev/null)" = 1 ] || return 0
  is_int "$t" || return 1
  led_legacy_conflict && { echo CONFLICT > "$LED_LAST";return 1; }
  led_supported || { echo UNSUPPORTED > "$LED_LAST";return 1; }
  # First cycle captures the normal brightness to restore when disabled.
  led_snapshot || { echo SNAPSHOT_FAILED > "$LED_LAST";return 1; }
  last=$(cat "$LED_LAST" 2>/dev/null)
  if [ "$t" -ge 65000 ] || { [ "$last" = RED ] && [ "$t" -ge 64000 ]; };then color=RED
  elif [ "$t" -ge 55000 ] || { [ "$last" = BLUE ] && [ "$t" -ge 54000 ]; };then color=BLUE
  else color=WHITE;fi
  [ "$color" = "$last" ] && return 0
  # Recheck enabled in case another command toggled OFF during this sample.
  [ "$(cat "$LED_ON" 2>/dev/null)" = 1 ] || return 0
  case "$color" in
    RED) led_write "$LED_BRIGHT" 0 0;;
    BLUE) led_write 0 0 "$LED_BRIGHT";;
    WHITE) led_write 0 "$LED_BRIGHT" 0;;
  esac || { echo WRITE_FAILED > "$LED_LAST";return 1; }
  printf '%s\n' "$color" > "$LED_LAST"
}
led_status() {
  echo LED_ON="$(cat "$LED_ON" 2>/dev/null)"
  if led_legacy_conflict;then echo LED_COMPAT=CONFLICT_OLD_PLUGIN
  elif led_supported;then echo LED_COMPAT=SUPPORTED
  else echo LED_COMPAT=UNSUPPORTED;fi
  echo LED_COLOR="$(cat "$LED_LAST" 2>/dev/null || echo OFF)"
}
led_config() {
  case "$1" in
    1)
      # Do not use an unverified maximum-of-all-thermal-zones temperature for LEDs.
      choice=$(cat "$ZONE" 2>/dev/null)
      [ "$choice" != auto ] && valid_zone "$choice" || { echo LED_SELECT_CPU_ZONE_FIRST;return 1; }
      led_legacy_conflict && { echo LED_CONFLICT_REMOVE_OLD_LED_PLUGIN_FIRST;return 1; }
      [ -z "$(legacy_led_pids)" ] || { echo LED_CONFLICT_OLD_PROCESS_RUNNING;return 1; }
      led_supported || { echo LED_UNSUPPORTED_HARDWARE;return 1; }
      valid_pid || { echo LED_START_MONITOR_FIRST;return 1; }
      led_snapshot || { echo LED_CANNOT_BACKUP_BRIGHTNESS;return 1; }
      echo 1 > "$LED_ON";echo LED_ENABLED;;
    0)
      echo 0 > "$LED_ON";led_restore;echo LED_DISABLED;;
    *) echo LED_BAD_ARGUMENT;return 1;;
  esac
}

read_temp() {
  choice=$(cat "$ZONE" 2>/dev/null)
  if [ "$choice" = auto ] || [ -z "$choice" ];then
    best=0
    for p in /sys/class/thermal/thermal_zone*;do
      [ -r "$p/temp" ] || continue
      ty=$(cat "$p/type" 2>/dev/null)
      case "$ty" in *chg*|*front*|*frame*|*wcn*|*usb*|*bcl*|*skin*|*back*) continue;; esac
      v=$(normalize "$(cat "$p/temp" 2>/dev/null)") || continue
      [ "$v" -le "$best" ] || best=$v
    done
    [ "$best" -gt 0 ] && echo "$best" || return 1
  else
    valid_zone "$choice" || return 1
    normalize "$(cat "/sys/class/thermal/$choice/temp" 2>/dev/null)"
  fi
}
scan() {
  printf 'ZONE|TYPE|MILLI_C\n'
  for p in /sys/class/thermal/thermal_zone*;do
    [ -r "$p/temp" ] || continue
    v=$(normalize "$(cat "$p/temp" 2>/dev/null)") || continue
    printf '%s|%s|%s\n' "${p##*/}" "$(cat "$p/type" 2>/dev/null)" "$v"
  done
}
load_rules() {
  set -- $(cat "$CFG" 2>/dev/null)
  [ "$#" -eq 6 ] || return 1
  for x in "$@";do is_int "$x" || return 1;done
  A=$1;AS=$2;B=$3;BS=$4;C=$5;CS=$6
  [ "$A" -ge 50000 ] && [ "$C" -le 85000 ] && [ "$A" -lt "$B" ] && [ "$B" -lt "$C" ] || return 1
  for d in "$AS" "$BS" "$CS";do [ "$d" -ge 60 ] && [ "$d" -le 3600 ] && [ $((d%60)) -eq 0 ] || return 1;done
}
valid_pid() {
  [ -r "$PID" ] || return 1
  p=$(cat "$PID" 2>/dev/null);is_int "$p" || return 1
  [ -r "/proc/$p/cmdline" ] || return 1
  tr '\000' ' ' < "/proc/$p/cmdline" | grep -Fq "$BIN"
}
boot_off() {
  [ -f "$BOOT" ] || return 0
  sed '/^# F50_ALERT_V6_START$/,/^# F50_ALERT_V6_END$/d' "$BOOT" > "$BOOT.f50alert.tmp" || return 1
  mv "$BOOT.f50alert.tmp" "$BOOT"
}
boot_on() {
  [ -f "$BOOT" ] || printf '#!/system/bin/sh\n' > "$BOOT" || return 1
  if ! grep -Fq '# F50_ALERT_V6_START' "$BOOT";then
    cat >> "$BOOT" <<'HOOK'
# F50_ALERT_V6_START
sh /data/local/tmp/f50_alert_v6/monitor.sh start >/dev/null 2>&1 &
# F50_ALERT_V6_END
HOOK
  fi
  chmod 755 "$BOOT" 2>/dev/null || true
}
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g;s/\r//g'; }
push_send() {
  [ -s "$TOKEN" ] || return 1
  command -v "$CURL" >/dev/null 2>&1 || return 1
  t=$(cat "$TOKEN" 2>/dev/null)
  case "$t" in ''|*[!A-Za-z0-9_-]*) return 1;; esac
  title=$(json_escape "$1");msg=$(json_escape "$2")
  format=${3:-txt}
  case "$format" in txt|html) :;; *) return 1;; esac
  printf '{"token":"%s","title":"%s","content":"%s","template":"%s","channel":"wechat"}' "$t" "$title" "$msg" "$format" > "$BASE/push_body.json" || return 1
  chmod 600 "$BASE/push_body.json" 2>/dev/null || true
  response=$("$CURL" -sS --connect-timeout 5 --max-time 12 -X POST 'https://www.pushplus.plus/send' -H 'Content-Type: application/json' --data-binary @"$BASE/push_body.json" 2>/dev/null)
  rm -f "$BASE/push_body.json"
  case "$response" in *'"code":200'*|*'"code": 200'*) return 0;; *) return 1;; esac
}
queue_notice() {
  [ "$(cat "$PUSH" 2>/dev/null)" = 1 ] || return 0
  code=$1;body=$2;now=$(date +%s)
  old=$(grep -F "$code " "$PUSH_SENT" 2>/dev/null | tail -n1 | awk '{print $2}')
  is_int "$old" || old=0
  case "$code" in DAILY_*) cooldown=0;; *) cooldown=1800;; esac
  [ $((now-old)) -ge "$cooldown" ] || return 0
  grep -v -F "$code " "$PUSH_SENT" > "$BASE/sent.tmp" 2>/dev/null || true
  printf '%s %s\n' "$code" "$now" >> "$BASE/sent.tmp"
  mv "$BASE/sent.tmp" "$PUSH_SENT"
  printf '%s|%s\n' "$code" "$body" >> "$QUEUE"
  n=$(wc -l < "$QUEUE" 2>/dev/null)
  [ "${n:-0}" -le 25 ] || { tail -n 25 "$QUEUE" > "$BASE/queue.tmp" && mv "$BASE/queue.tmp" "$QUEUE"; }
  logit "PUSH_QUEUED $code"
}
flush_notice() {
  [ "$(cat "$PUSH" 2>/dev/null)" = 1 ] || return 0
  [ -s "$QUEUE" ] || return 0
  now=$(date +%s)
  [ $((now-${LAST_SEND:-0})) -ge 120 ] || return 0
  LAST_SEND=$now
  first=$(head -n1 "$QUEUE");kind=${first%%|*};msg=${first#*|}
  fmt=txt
  case "$kind" in DAILY_*) fmt=html;; esac
  if push_send "F50 $kind" "$msg" "$fmt";then
    tail -n +2 "$QUEUE" > "$BASE/queue.tmp" && mv "$BASE/queue.tmp" "$QUEUE"
    logit "PUSH_ACCEPTED $kind (delivery unconfirmed)"
  else logit "PUSH_FAILED $kind (retry 120s)";fi
}
# Native ZTE goform read-only counters; don't request private device identifiers.
# Compatibility: native reads must traverse authenticated UFI-TOOLS proxy or ZTE's 8080 API.
# The bundled signed read-only clients are preferred; never ask for or store a modem password.
UFI_BIN=/data/data/com.minikano.f50_sms/files/ufi_req
ZTE_BIN=/data/data/com.minikano.f50_sms/files/zreq
NATIVE_SRC=$BASE/native_source
native_valid() {
  case "$1" in
    *'"monthly_rx_bytes"'*|*'"flux_monthly_rx_bytes"'*|*'"Z5g_rsrp"'*|*'"lte_rsrp"'*|*'"network_information"'*) return 0;;
  esac
  return 1
}
goform_fetch() {
  cmd=$1
  # Local signed HTTP client can read the UFI session token without exposing it here.
  if [ -x "$UFI_BIN" ];then
    body=$("$UFI_BIN" -X GET -t 6 -e "/api/goform/goform_get_cmd_process?isTest=false&multi_data=1&cmd=$cmd" 2>/dev/null)
    if native_valid "$body";then printf '%s' "$body";echo ufi_req > "$NATIVE_SRC";return 0;fi
  fi
  # The ZTE client handles its own local 8080 login. It may be unavailable on some builds.
  if [ -x "$ZTE_BIN" ];then
    body=$("$ZTE_BIN" -method GET -params "cmd=$cmd&multi_data=1" -json 2>/dev/null)
    if native_valid "$body";then printf '%s' "$body";echo zreq > "$NATIVE_SRC";return 0;fi
  fi
  # Some F50 firmware variants allow anonymous read-only queries on port 8080.
  body=$("$CURL" -fsS --connect-timeout 2 --max-time 4 \
    -H 'Referer: http://192.168.0.1:8080/index.html' \
    "http://192.168.0.1:8080/goform/goform_get_cmd_process?isTest=false&multi_data=1&cmd=$cmd" 2>/dev/null)
  if native_valid "$body";then printf '%s' "$body";echo zte_8080 > "$NATIVE_SRC";return 0;fi
  return 1
}
json_number() {
  # The returned JSON contains a mix of numeric and numeric-string values.
  printf '%s' "$2" | sed 's/\\"/"/g' | tr ',;' '\n\n' | awk -F: -v k="$1" '
    NF>=2 {name=$1;gsub(/[[:space:]"{}\\]/,"",name);if(name==k){
       value=$2;gsub(/[[:space:]"{}\\]/,"",value)
       if(value ~ /^-?[0-9]+(\.[0-9]+)?$/){print value;exit}
    }}'
}
int_of() { awk -v x="$1" 'BEGIN { if(x ~ /^[0-9]+$/) printf "%.0f", x;else print "" }'; }
# Read F50's native counters; fall back to an existing cellular interface, never wifi/USB traffic.
read_cellular_bytes() {
  dev=''
  for i in /sys/class/net/*; do
    [ -r "$i/statistics/rx_bytes" ] || continue
    n=${i##*/}
    case "$n" in sipa*|rmnet*|ccmni*|wwan*|pdp*) dev=$n;break;; esac
  done
  [ -n "$dev" ] || { echo 'NA|NA';return; }
  rx=$(cat "/sys/class/net/$dev/statistics/rx_bytes" 2>/dev/null)
  tx=$(cat "/sys/class/net/$dev/statistics/tx_bytes" 2>/dev/null)
  is_int "$rx" && is_int "$tx" || { echo 'NA|NA';return; }
  total=$(bytes_add "$rx" "$tx") || { echo 'NA|NA';return; }
  echo "$dev|$total"
}
# A consistent, conservative ledger. The modem's "monthly" absolute counter has
# its own reset convention, so never compare it directly to sampled daily usage.
# First observation, source switches and counter resets each establish a new baseline.
# A large gap is counted for the day/month only if it fits entirely within the day;
# it is omitted from hourly bars because the hour cannot be determined.
flow_update() {
  nowday=$(date +%Y%m%d);nowmon=$(date +%Y%m);nowts=$(date +%s)
  source='';total='';native=NA
  gojson=$(goform_fetch 'monthly_rx_bytes,monthly_tx_bytes,Z5g_rsrp,lte_rsrp,network_information,network_type,Z5g_SINR,lte_snr,network_sinr')
  rx=$(json_number flux_monthly_rx_bytes "$gojson");tx=$(json_number flux_monthly_tx_bytes "$gojson")
  if ! is_int "$rx" || ! is_int "$tx";then
    rx=$(json_number monthly_rx_bytes "$gojson");tx=$(json_number monthly_tx_bytes "$gojson")
    if is_int "$rx" && is_int "$tx";then source='goform_monthly';fi
  else source='goform_flux_monthly';fi
  if [ -n "$source" ];then
    total=$(bytes_add "$rx" "$tx") || { FLOW_DAY=-1;FLOW_MONTH=-1;FLOW_DEV=unavailable;echo UNSAFE_COUNTER > "$FLOWQUALITY";return 1; };native=$total
  else
    line=$(read_cellular_bytes);dev=${line%%|*};total=${line#*|}
    [ "$dev" != NA ] && is_int "$total" || { FLOW_DAY=-1;FLOW_MONTH=-1;FLOW_DEV=unavailable;echo UNAVAILABLE > "$FLOWQUALITY";return 1; }
    source="sysfs_$dev"
  fi
  prevday='';prevmon='';prevdev='';prevtotal=0;dd=0;mm=0;prevts=0
  if [ -r "$FLOW" ];then read -r prevday prevmon prevdev prevtotal dd mm prevts < "$FLOW";fi
  is_int "$prevtotal" || prevtotal=0
  is_int "$prevts" || prevts=0
  is_int "$dd" || dd=0
  is_int "$mm" || mm=0
  [ "$prevday" = "$nowday" ] || dd=0
  [ "$prevmon" = "$nowmon" ] || mm=0
  delta=0;bar_delta=0;quality=BASELINE
  if [ -n "$prevdev" ];then
    if [ "$prevdev" != "$source" ];then quality=SOURCE_SWITCH
    elif [ "$prevmon" != "$nowmon" ];then quality=MONTH_BOUNDARY
    elif [ "$prevday" != "$nowday" ];then quality=DAY_BOUNDARY
    elif [ "$nowts" -le "$prevts" ];then quality=CLOCK_CHANGE
    elif bytes_lt "$total" "$prevtotal";then quality=COUNTER_RESET
    else
      delta=$(bytes_sub "$total" "$prevtotal") || { echo BAD_DELTA > "$FLOWQUALITY";return 1; }
      dd=$(bytes_add "$dd" "$delta") || { echo UNSAFE_DAY_TOTAL > "$FLOWQUALITY";return 1; }
      mm=$(bytes_add "$mm" "$delta") || { echo UNSAFE_MONTH_TOTAL > "$FLOWQUALITY";return 1; }
      quality=OK
      # For missing polling windows, the *total* is still known but hourly
      # attribution is unknown; avoid rendering a fake single-hour spike.
      if [ $((nowts-prevts)) -le 180 ];then
        bar_delta=$delta
      else
        quality=GAP_UNALLOCATED
      fi
    fi
  fi
  [ -r "$FLOWSINCE" ] || printf '%s
' "$nowts" > "$FLOWSINCE"
  printf '%s %s %s %s %s %s %s
' "$nowday" "$nowmon" "$source" "$total" "$dd" "$mm" "$nowts" > "$BASE/flow.tmp" && mv "$BASE/flow.tmp" "$FLOW"
  printf '%s|%s|%s
' "$native" "$nowts" "$source" > "$FLOWRAW"
  printf '%s
' "$quality" > "$FLOWQUALITY"
  FLOW_DAY=$dd;FLOW_MONTH=$mm;FLOW_DEV=$source
  printf '%s|%s|%s|%s
' "$nowts" "$bar_delta" "$dd" "$mm" >> "$FLOWHIST"
  n=$(wc -l < "$FLOWHIST" 2>/dev/null)
  [ "${n:-0}" -le 3100 ] || { tail -n 3000 "$FLOWHIST" > "$BASE/flowhist.tmp" && mv "$BASE/flowhist.tmp" "$FLOWHIST"; }
  [ "$quality" = OK ] || logit "FLOW_BASELINE $quality source=$source; no fabricated hourly increment"
}

signal_probe() {
  # In particular, do NOT request nr_rsrp/nr_rsrq/Nr_snr together with network_information:
  # certain F50 firmwares blank network_information fields when doing so.
  raw=$(goform_fetch 'monthly_rx_bytes,monthly_tx_bytes,Z5g_rsrp,lte_rsrp,network_information,network_type,Z5g_SINR,lte_snr,network_sinr')
  rsrp=$(json_number Z5g_rsrp "$raw")
  awk -v x="$rsrp" 'BEGIN{exit !(x>=-140 && x<=-40)}' || rsrp=''
  [ -n "$rsrp" ] || rsrp=$(json_number lte_rsrp "$raw")
  sinr=$(json_number Z5g_SINR "$raw")
  [ -n "$sinr" ] || sinr=$(json_number lte_snr "$raw")
  [ -n "$sinr" ] || sinr=$(json_number network_sinr "$raw")
  # Some F50 firmware stores NR metrics inside network_information, using
  # alternate spellings. No explicit nr_rsrp/Nr_snr request (may clear dump).
  if [ -z "$sinr" ];then
    dump=$(goform_fetch 'network_information')
    for k in Z5g_snr Nr_snr nr_sinr nrsinr Z_SINR lte_sinr LTE_SINR SINR;do
      sinr=$(json_number "$k" "$dump")
      [ -n "$sinr" ] && break
    done
  fi
  # Some modems express SINR in tenths of a dB; reject unrecognized ranges.
  rsrp=$(awk -v x="$rsrp" 'BEGIN{if(x ~ /^-[0-9]+(\.[0-9]+)?$/ && x>=-140 && x<=-40)printf "%.0f",x;else print "NA"}')
  sinr=$(awk -v x="$sinr" 'BEGIN{if(x !~ /^-?[0-9]+(\.[0-9]+)?$/)print "NA";else if(x>=-40 && x<=40)printf "%.0f",x;else if(x>40 && x<=400)printf "%.0f",x/10;else print "NA"}')
  SIGNAL_RSRP=$rsrp;SIGNAL_SINR=$sinr
  printf '%s|%s|%s|%s\n' "$(date +%s)" "$rsrp" "$sinr" "${t:-0}" >> "$SIGNAL"
  n=$(wc -l < "$SIGNAL" 2>/dev/null)
  [ "${n:-0}" -le 3100 ] || { tail -n 3000 "$SIGNAL" > "$BASE/signal.tmp" && mv "$BASE/signal.tmp" "$SIGNAL"; }
}
telemetry_diag() {
  # Only signal/traffic counters, never IMEI, SIM identifiers or token.
  [ -x "$UFI_BIN" ] && echo UFI_REQ=PRESENT || echo UFI_REQ=MISSING
  [ -x "$ZTE_BIN" ] && echo ZREQ=PRESENT || echo ZREQ=MISSING
  g=$(goform_fetch 'monthly_rx_bytes,monthly_tx_bytes,Z5g_rsrp,lte_rsrp,network_information,network_type,Z5g_SINR,lte_snr,network_sinr')
  if [ -n "$g" ];then
    echo 'GOFORM=OK'
    for k in flux_monthly_rx_bytes flux_monthly_tx_bytes monthly_rx_bytes monthly_tx_bytes;do
      x=$(json_number "$k" "$g");echo "${k}=${x:-NA}"
    done
  else echo 'GOFORM=UNAVAILABLE';fi
  s=$(goform_fetch 'monthly_rx_bytes,monthly_tx_bytes,Z5g_rsrp,lte_rsrp,network_information,network_type,Z5g_SINR,lte_snr,network_sinr')
  if [ -n "$s" ];then
    echo 'RADIO_API=OK'
    for k in Z5g_rsrp lte_rsrp Z5g_SINR lte_snr network_sinr network_signalbar;do
      x=$(json_number "$k" "$s");echo "${k}=${x:-NA}"
    done
  else echo 'RADIO_API=UNAVAILABLE';fi
  src=$(cat "$NATIVE_SRC" 2>/dev/null);echo "NATIVE_SOURCE=${src:-NONE}"
  fb=$(read_cellular_bytes);echo "SYSFS_FALLBACK=$fb"
  echo 'SYSFS is a raw counter since interface reset; zero increment at the first sample is expected.'
  [ -r "$FLOW" ] && cat "$FLOW" | sed 's/^/FLOW_V101_STATE=/'
}
# Daily summary: samples, sum(milliC), max/min, over-threshold seconds, radio averages, flow deltas.
stats_load() {
  TODAY=$(date +%Y%m%d)
  if [ -r "$STATS" ];then
    set -- $(cat "$STATS")
    if [ "$1" = "$TODAY" ] && [ "$#" -eq 17 ];then
      SN=$2;SUM=$3;MAX=$4;MIN=$5;D60=$6;D65=$7;D70=$8;D75=$9
      shift 9
      SGN=$1;SGSUM=$2;SINN=$3;SINSUM=$4;WEAK=$5;STRONG=$6;FD=$7;FM=$8
      return 0
    fi
    cp "$STATS" "$YDAY" 2>/dev/null || true
  fi
  SN=0;SUM=0;MAX=0;MIN=0;D60=0;D65=0;D70=0;D75=0;SGN=0;SGSUM=0;SINN=0;SINSUM=0;WEAK=0;STRONG=0;FD=-1;FM=-1
}
stats_save() {
  printf '%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s\n' "$TODAY" "$SN" "$SUM" "$MAX" "$MIN" "$D60" "$D65" "$D70" "$D75" "$SGN" "$SGSUM" "$SINN" "$SINSUM" "$WEAK" "$STRONG" "$FD" "$FM" > "$BASE/stats.tmp"
  mv "$BASE/stats.tmp" "$STATS"
}
stats_summary() {
  [ -r "$1" ] || { echo NONE;return; }
  awk '{if($2>0){printf "DATE=%s SAMPLES=%d MAX=%.1f AVG=%.1f MIN=%.1f OVER60=%d OVER65=%d OVER70=%d OVER75=%d SIGNALN=%d RSRP_AVG=%s SINR_AVG=%s WEAK=%d STRONG=%d FLOW_DAY=%.0f FLOW_MON=%.0f\n",$1,$2,$4/1000,$3/$2/1000,$5/1000,$6,$7,$8,$9,$10,($10>0?sprintf("%.1f",$11/$10):"NA"),($12>0?sprintf("%.1f",$13/$12):"NA"),$14,$15,$16,$17}else print "NONE"}' "$1"
}
report_text() {
  f=$1;[ -r "$f" ] || return 1
  set -- $(cat "$f")
  [ "$#" -eq 17 ] || return 1
  d=$1;samp=$2;sum=$3;mx=$4;mn=$5;s60=$6;s65=$7;s70=$8;s75=$9;shift 9
  sigcnt=$1;sigsum=$2;sinn=$3;sinsum=$4;weak=$5;strong=$6;dyflow=$7;monflow=$8
  [ "$samp" -gt 0 ] || return 1
  av=$(awk -v a="$sum" -v b="$samp" 'BEGIN{printf "%.1f",a/b/1000}')
  ma=$(awk -v a="$mx" 'BEGIN{printf "%.1f",a/1000}')
  min=$(awk -v a="$mn" 'BEGIN{printf "%.1f",a/1000}')
  if is_int "$dyflow";then dy=$(awk -v a="$dyflow" 'BEGIN{printf "%.2f",a/1000000000}');else dy=不可用;fi
  if is_int "$monflow";then mo=$(awk -v a="$monflow" 'BEGIN{printf "%.2f",a/1000000000}');else mo=不可用;fi
  if [ "$sigcnt" -gt 0 ];then
    sr=$(awk -v a="$sigsum" -v b="$sigcnt" 'BEGIN{printf "%.1f",a/b}')
    if [ "$sinn" -gt 0 ];then si=$(awk -v a="$sinsum" -v b="$sinn" 'BEGIN{printf "%.1f",a/b}');else si=NA;fi
    sig="平均RSRP $sr dBm；平均SINR $si dB；弱信号样本 $weak/$sigcnt"
  else sig='RSRP/SINR不可用';fi
  printf '日期：%s\n温度最高/平均/最低：%s/%s/%s ℃\n高于60/65/70/75℃累计：%s/%s/%s/%s 分钟\n蜂窝流量今日/本月监控增量（升级后累计）：%s/%s GB\n信号统计：%s\n当前为纯提醒模式：不自动关机或断网。\n' "$d" "$ma" "$av" "$min" "$((s60/60))" "$((s65/60))" "$((s70/60))" "$((s75/60))" "$dy" "$mo" "$sig"
}

# SVG is embedded directly in HTML, matching the older F50 temperature-report plugin.
# No external chart host or subscription required; WeChat renderer support still needs device test.
svg_temp() {
  from=$1;to=$2
  [ -s "$HISTORY" ] || return 1
  awk -F'|' -v s="$from" -v e="$to" '
  $1>=s && $1<e && $2>=15000 && $2<=105000 {i=int(($1-s)/300);sum[i]+=$2/1000;n[i]++}
  END{
    pts=0;vmin=999;vmax=-999;
    for(i=0;i<288;i++)if(n[i]>0){v=sum[i]/n[i];a[i]=v;pts++;if(v<vmin)vmin=v;if(v>vmax)vmax=v}
    if(pts<2)exit
    lo=int((vmin-4)/5)*5;hi=int((vmax+9)/5)*5;if(hi-lo<12)hi=lo+12
    W=620;H=244;L=47;R=14;T=25;B=30;pw=W-L-R;ph=H-T-B
    print "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 620 244\" width=\"100%\" style=\"max-width:620px;border-radius:12px;background:#0d192d\">"
    print "<defs><linearGradient id=\"f50tv6\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0%\" stop-color=\"#4de1ce\" stop-opacity=\".34\"/><stop offset=\"100%\" stop-color=\"#4de1ce\" stop-opacity=\"0\"/></linearGradient></defs>"
    print "<text x=\"17\" y=\"17\" fill=\"#edf7ff\" font-size=\"12\" font-weight=\"bold\">F50 CPU/SoC 温度 · 按整点显示</text>"
    for(j=0;j<=4;j++){
       val=lo+(hi-lo)*j/4;y=T+ph-ph*j/4
       printf "<path d=\"M%d %.1f H%d\" stroke=\"#2b4059\" stroke-width=\".65\"/><text x=\"7\" y=\"%.1f\" fill=\"#a6bdd3\" font-size=\"10\">%.0f°</text>",L,y,W-R,y+3,val
    }
    for(k=1;k<=3;k++){th=(k==1?65:(k==2?70:75));color=(k==1?"#eebf59":(k==2?"#ef9059":"#e55d81"));if(th>=lo&&th<=hi){y=T+ph-(th-lo)*ph/(hi-lo);printf "<path d=\"M%d %.1f H%d\" stroke=\"%s\" stroke-dasharray=\"6 5\" stroke-width=\"1\"/><text x=\"%d\" y=\"%.1f\" text-anchor=\"end\" fill=\"%s\" font-size=\"10\">%d℃</text>",L,y,W-R,color,W-R-2,y-4,color,th}}
    d="";first=-1;last=-1
    for(i=0;i<288;i++)if(n[i]>0){x=L+i/287*pw;y=T+ph-(a[i]-lo)*ph/(hi-lo);d=d (first<0?"M":"L") sprintf("%.1f,%.1f ",x,y);if(first<0)first=x;last=x}
    printf "<path d=\"%sL%.1f,%d L%.1f,%d Z\" fill=\"url(#f50tv6)\"/>",d,last,T+ph,first,T+ph
    printf "<path d=\"%s\" fill=\"none\" stroke=\"#66ebd7\" stroke-width=\"2.3\" stroke-linejoin=\"round\"/>\n",d
    for(hour=0;hour<24;hour++){
      ax=47+(hour+0.5)*559/24
      printf "<text x=\"%.1f\" y=\"234\" font-size=\"8\" text-anchor=\"middle\" fill=\"#a9bfd5\">%02d点</text>",ax,hour
    }
    printf "<text x=\"605\" y=\"17\" text-anchor=\"end\" font-size=\"10\" fill=\"#97e9d9\">最低 %.1f° · 最高 %.1f°</text>",vmin,vmax
    print "</svg>"
  }' "$HISTORY"
}
svg_flow() {
  from=$1;to=$2
  [ -s "$FLOWHIST" ] || return 1
  awk -F'|' -v s="$from" -v e="$to" '
  $1>=s && $1<e && $2>=0 {i=int(($1-s)/3600);if(i>=0&&i<24){v[i]+=$2/1000000;n[i]++}}
  END{
    c=0;mx=0;for(i=0;i<24;i++)if(n[i]>0){c++;if(v[i]>mx)mx=v[i]}
    if(!c)exit
    if(mx<1)mx=1
    print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" viewBox=\"0 0 620 190\" style=\"max-width:620px;border-radius:12px;background:#0d192d\">"
    print "<text x=\"17\" y=\"17\" fill=\"#edf7ff\" font-size=\"12\" font-weight=\"bold\">F50 蜂窝流量 · 每小时增量（MB）</text>"
    for(i=0;i<=3;i++){y=162-i*38;printf "<path d=\"M45 %d H606\" stroke=\"#28405b\" stroke-width=\".7\"/>\n",y}
    for(i=0;i<24;i++){h=v[i]/mx*112;x=49+i*23; if(h>0)printf "<rect x=\"%.0f\" y=\"%.1f\" width=\"15\" height=\"%.1f\" rx=\"3\" fill=\"#48bdf2\"/>\n",x,162-h,h}
    for(hour=0;hour<24;hour++){
      ax=45+(hour+0.5)*561/24
      printf "<text x=\"%.1f\" y=\"181\" font-size=\"8\" text-anchor=\"middle\" fill=\"#a9bfd5\">%02d点</text>",ax,hour
    }
    printf "<text x=\"606\" y=\"17\" text-anchor=\"end\" fill=\"#b4dff5\" font-size=\"10\">峰值 %.1f MB/h</text>",mx
    print "</svg>"
  }' "$FLOWHIST"
}
svg_signal() {
  from=$1;to=$2
  [ -s "$SIGNAL" ] || return 1
  awk -F'|' -v s="$from" -v e="$to" '
  $1>=s && $1<e {
     i=int(($1-s)/3600);if(i<0||i>23)next
     if($2!="NA"&&$2>=-140&&$2<=-40){rs[i]+=$2;rn[i]++}
     if($3!="NA"&&$3>=-40&&$3<=40){ss[i]+=$3;sn[i]++}
  }
  END{
    n=0;for(i=0;i<24;i++)if(rn[i]||sn[i])n++
    if(n<2)exit
    print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" viewBox=\"0 0 620 190\" style=\"max-width:620px;border-radius:12px;background:#0d192d\">"
    print "<text x=\"17\" y=\"17\" fill=\"#edf7ff\" font-size=\"12\" font-weight=\"bold\">F50 信号 · RSRP（左轴）/ SINR（右轴）</text>"
    for(i=0;i<=3;i++){y=163-i*38;printf "<path d=\"M51 %d H563\" stroke=\"#28405b\" stroke-width=\".65\"/>\n",y}
    p="";q="";last1=-2;last2=-2
    for(i=0;i<24;i++){
      x=54+(i+.5)/24*502
      if(rn[i]){v=rs[i]/rn[i];y=163-(v+140)/100*125;p=p ((last1==i-1)?"L":"M") sprintf("%.1f,%.1f ",x,y);last1=i}
      if(sn[i]){v=ss[i]/sn[i];y=163-(v+40)/80*125;q=q ((last2==i-1)?"L":"M") sprintf("%.1f,%.1f ",x,y);last2=i}
    }
    if(p!="")printf "<path d=\"%s\" fill=\"none\" stroke=\"#56b9ed\" stroke-width=\"2.2\"/>\n",p
    if(q!="")printf "<path d=\"%s\" fill=\"none\" stroke=\"#efbc5e\" stroke-width=\"2.2\"/>\n",q
    print "<text x=\"20\" y=\"36\" fill=\"#56b9ed\" font-size=\"10\">-40</text><text x=\"15\" y=\"166\" fill=\"#56b9ed\" font-size=\"10\">-140</text><text x=\"574\" y=\"36\" fill=\"#efbc5e\" font-size=\"10\">40</text><text x=\"574\" y=\"166\" fill=\"#efbc5e\" font-size=\"10\">-40</text>"
    for(hour=0;hour<24;hour++){
      ax=51+(hour+0.5)*512/24
      printf "<text x=\"%.1f\" y=\"182\" font-size=\"8\" text-anchor=\"middle\" fill=\"#a9bfd5\">%02d点</text>",ax,hour
    }
    print "</svg>"
  }' "$SIGNAL"
}

report_html() {
  f=$1;[ -r "$f" ] || return 1
  set -- $(cat "$f")
  [ "$#" -eq 17 ] || return 1
  d=$1;samp=$2;sum=$3;mx=$4;mn=$5;s60=$6;s65=$7;s70=$8;s75=$9;shift 9
  sigcnt=$1;sigsum=$2;sinn=$3;sinsum=$4;weak=$5;strong=$6;dyflow=$7;monflow=$8
  [ "$samp" -gt 0 ] || return 1
  av=$(awk -v a="$sum" -v b="$samp" 'BEGIN{printf "%.1f",a/b/1000}')
  ma=$(awk -v a="$mx" 'BEGIN{printf "%.1f",a/1000}')
  mi=$(awk -v a="$mn" 'BEGIN{printf "%.1f",a/1000}')
  if is_int "$dyflow";then dy=$(awk -v a="$dyflow" 'BEGIN{printf "%.2f",a/1000000000}')' GB';else dy='不可用';fi
  if is_int "$monflow";then mo=$(awk -v a="$monflow" 'BEGIN{printf "%.2f",a/1000000000}')' GB';else mo='不可用';fi
  if [ "$sigcnt" -gt 0 ];then
    sr=$(awk -v a="$sigsum" -v b="$sigcnt" 'BEGIN{printf "%.1f",a/b}')' dBm'
  else sr='不可用';fi
  if [ "$sinn" -gt 0 ];then si=$(awk -v a="$sinsum" -v b="$sinn" 'BEGIN{printf "%.1f",a/b}')' dB';else si='不可用';fi
  percent='--'
  [ "$sigcnt" -eq 0 ] || percent=$(awk -v a="$weak" -v b="$sigcnt" 'BEGIN{printf "%.1f%%",a*100/b}')
  since=$(printf '%s' "$d" | sed 's/^\(....\)\(..\)\(..\)$/\1-\2-\3/')
  case "$s75" in 0) conclusion='今日无75℃以上严重超温';; *) conclusion='出现过75℃以上严重高温，请检查背包散热';; esac
  printf '<div style="font-family:Arial,sans-serif;max-width:640px;margin:auto;color:#17243d;background:#f4f7fc;padding:14px;border-radius:14px"><div style="background:#122238;color:#ffffff;padding:16px;border-radius:12px"><div style="font-size:12px;letter-spacing:1px;color:#7bd9cc">F50 · DEVICE HEALTH</div><h2 style="font-size:20px;margin:5px 0">F50 每日健康报告</h2><div style="color:#d3e2f1">%s · 纯只读监控</div></div>' "$since"
  printf '<h3 style="color:#173a66">01 · 关键数据总览</h3><table style="width:100%%;border-collapse:collapse;font-size:13px"><tr style="background:#dae9f7"><th style="padding:8px;border:1px solid #cbd7e6">指标</th><th style="padding:8px;border:1px solid #cbd7e6">结果</th></tr>'
  printf '<tr><td style="padding:8px;border:1px solid #cbd7e6">温度最高/平均/最低</td><td style="padding:8px;border:1px solid #cbd7e6">%s / %s / %s ℃</td></tr>' "$ma" "$av" "$mi"
  printf '<tr><td style="padding:8px;border:1px solid #cbd7e6">今日监控流量增量</td><td style="padding:8px;border:1px solid #cbd7e6">%s</td></tr>' "$dy"
  printf '<tr><td style="padding:8px;border:1px solid #cbd7e6">本月监控流量增量</td><td style="padding:8px;border:1px solid #cbd7e6">%s</td></tr>' "$mo"
  printf '<tr><td style="padding:8px;border:1px solid #cbd7e6">平均 RSRP / SINR</td><td style="padding:8px;border:1px solid #cbd7e6">%s / %s</td></tr></table>' "$sr" "$si"
  printf '<h3 style="color:#173a66">02 · 超温与信号统计</h3><table style="width:100%%;border-collapse:collapse;font-size:13px"><tr style="background:#dae9f7"><th style="padding:8px;border:1px solid #cbd7e6">指标</th><th style="padding:8px;border:1px solid #cbd7e6">统计</th></tr>'
  printf '<tr><td style="padding:8px;border:1px solid #cbd7e6">≥60 / 65 / 70 / 75 ℃</td><td style="padding:8px;border:1px solid #cbd7e6">%s / %s / %s / %s 分钟</td></tr>' "$((s60/60))" "$((s65/60))" "$((s70/60))" "$((s75/60))"
  printf '<tr><td style="padding:8px;border:1px solid #cbd7e6">弱信号样本（RSRP≤-105）</td><td style="padding:8px;border:1px solid #cbd7e6">%s / %s，%s</td></tr></table>' "$weak" "$sigcnt" "$percent"
  printf '<p style="background:#e6f2ec;padding:10px;border-radius:8px;font-size:13px">今日结论：%s。统计仅代表采样期间，设备不会自动关机或断网。</p>' "$conclusion"
  # Inline SVG images have been used successfully by the older F50 monitor plugin.
  from=$(date -d "$since 00:00:00" +%s 2>/dev/null)
  if is_int "$from" && [ "$from" -gt 0 ];then
    to=$((from+86400))
    chart=$(svg_temp "$from" "$to")
    if [ -n "$chart" ];then
      printf '<h3 style="color:#173a66">03 · 24小时温度折线图</h3>%s' "$chart"
    else printf '<p>温度样本不足，暂时无法生成24小时折线图。</p>';fi
    chart=$(svg_flow "$from" "$to")
    if [ -n "$chart" ];then
      printf '<h3 style="color:#173a66">04 · 24小时流量柱状图</h3>%s' "$chart"
    else printf '<p>分时流量样本不足，暂时无法生成流量图。</p>';fi
    chart=$(svg_signal "$from" "$to")
    if [ -n "$chart" ];then
      printf '<h3 style="color:#173a66">05 · 24小时信号双轴曲线</h3>%s' "$chart"
    else printf '<p>信号采样不足，暂时无法生成信号图。</p>';fi
  else printf '<p>设备日期转换不可用，本次仅包含统计表格。</p>';fi
  printf '<p style="font-size:11px;color:#64748b">今日和本月均由首次有效采样起同源连续增量累计；原厂计数可在插件页面单独查看，重启或源切换期间存在遗漏；不是运营商账单。图表使用内嵌SVG，实际微信展示以收到的内容为准。</p></div>'
}

report_daily() {
  [ "$(cat "$DAILY" 2>/dev/null)" = 1 ] || return 0
  [ "$(cat "$PUSH" 2>/dev/null)" = 1 ] || return 0
  hour=$(cat "$HOUR" 2>/dev/null)
  is_int "$hour" || hour=08
  [ "$(date +%H)" -ge "$hour" ] || return 0
  flag=$(cat "$REPORT_MARK" 2>/dev/null)
  [ "$flag" = "$TODAY" ] && return 0
  [ -r "$YDAY" ] || return 0
  summary=$(report_html "$YDAY") || return 0
  summary=$(printf '%s' "$summary" | tr '\n' ' ')
  queue_notice "DAILY_$(awk '{print $1}' "$YDAY")" "$summary"
  printf '%s\n' "$TODAY" > "$REPORT_MARK"
}
alert_brief() {
  cur_s='RSRP未知'
  [ -r "$SIGNAL" ] && { last_s=$(tail -n 1 "$SIGNAL");rs=$(printf '%s' "$last_s" | cut -d'|' -f2);[ "$rs" = NA ] || cur_s="RSRP ${rs}dBm"; }
  cur_f='今日流量未知'
  if [ -r "$FLOW" ];then read -r fday fmon fdev ftot fdb fmb < "$FLOW";case "$fdb" in ''|*[!0-9]*) :;; *) cur_f="今日$(awk -v x="$fdb" 'BEGIN{printf "%.2fGB",x/1000000000}')";;esac;fi
  printf '当前%s℃；%s；%s；%s。' "$((t/1000))" "$cur_s" "$cur_f" "$(date '+%H:%M')"
}
write_history() {
  minute=$((now/60));[ "$minute" = "$LAST_MIN" ] && return 0
  LAST_MIN=$minute
  printf '%s|%s\n' "$now" "$t" >> "$HISTORY"
  n=$(wc -l < "$HISTORY" 2>/dev/null)
  [ "${n:-0}" -le 3100 ] || { tail -n 3000 "$HISTORY" > "$BASE/history.tmp" && mv "$BASE/history.tmp" "$HISTORY"; }
}
selftest() {
  load_rules || { echo SELFTEST_RULES_FAILED;return 1; }
  [ "$A" -lt "$B" ] && [ "$B" -lt "$C" ] || { echo SELFTEST_ORDER_FAILED;return 1; }
  echo 'SELFTEST_OK READ_ONLY no_shutdown_no_network_commands'
}
run() {
  if valid_pid;then echo ALREADY_RUNNING;return 0;fi
  load_rules || { echo RULES_INVALID;return 1; }
  echo $$ > "$PID"
  trap 'stats_save;led_restore;rm -f "$PID"' EXIT
  trap 'exit 0' INT TERM HUP
  stats_load
  LAST_MIN=-1;LAST_SAMP=0;LAST_STATS=0;LAST_SIG=0;LAST_FLOW=0;LAST_SEND=0;RISE_AT=0;RISE_START=0;RISE_ARMED=1
  T1=0;T2=0;T3=0;ARM1=1;ARM2=1;ARM3=1;COOL_FROM=0
  LAST_CONF=''
  logit 'START MONITOR_ONLY no_shutdown no_data_toggle'
  while true;do
    conf="$(cat "$CFG" 2>/dev/null)|$(cat "$ZONE" 2>/dev/null)"
    if [ "$conf" != "$LAST_CONF" ];then
      load_rules || { logit 'INVALID_CONFIG';sleep "$INTERVAL";continue; }
      T1=0;T2=0;T3=0;ARM1=1;ARM2=1;ARM3=1;COOL_FROM=0;LAST_CONF=$conf
    fi
    now=$(date +%s)
    if [ "$(date +%Y%m%d)" != "$TODAY" ];then stats_save;stats_load;fi
    t=$(read_temp 2>/dev/null)
    case "$t" in ''|*[!0-9]*) printf 'ERR|%s\n' "$now" > "$REC";logit 'TEMPERATURE_READ_FAILED';sleep "$INTERVAL";continue;; esac
    dt=0;[ "$LAST_SAMP" -gt 0 ] && [ "$now" -ge "$LAST_SAMP" ] && [ $((now-LAST_SAMP)) -le 25 ] && dt=$((now-LAST_SAMP));LAST_SAMP=$now
    SN=$((SN+1));SUM=$((SUM+t));[ "$t" -gt "$MAX" ] && MAX=$t
    { [ "$MIN" -eq 0 ] || [ "$t" -lt "$MIN" ]; } && MIN=$t
    [ "$t" -ge 60000 ] && D60=$((D60+dt))
    [ "$t" -ge 65000 ] && D65=$((D65+dt))
    [ "$t" -ge 70000 ] && D70=$((D70+dt))
    [ "$t" -ge 75000 ] && D75=$((D75+dt))
    write_history
    led_apply || true
    [ "$t" -ge "$A" ] && { [ "$T1" -gt 0 ] || T1=$now; } || T1=0
    [ "$t" -ge "$B" ] && { [ "$T2" -gt 0 ] || T2=$now; } || T2=0
    [ "$t" -ge "$C" ] && { [ "$T3" -gt 0 ] || T3=$now; } || T3=0
    # Re-arm only after 3 minutes below tier-1 (prevents noisy repeated notifications).
    if [ "$t" -lt "$A" ];then [ "$COOL_FROM" -gt 0 ] || COOL_FROM=$now;else COOL_FROM=0;fi
    if [ "$COOL_FROM" -gt 0 ] && [ $((now-COOL_FROM)) -ge 180 ];then ARM1=1;ARM2=1;ARM3=1;fi
    tier=0
    brief=$(alert_brief)
    if [ "$T1" -gt 0 ] && [ $((now-T1)) -ge "$AS" ];then tier=1;[ "$ARM1" -eq 1 ] && { queue_notice WARN "温度提醒：超过 $((A/1000))℃ 已持续 $((AS/60))分钟。$brief 建议检查散热和通风。";ARM1=0;logit 'ALERT_TIER_1'; };fi
    if [ "$T2" -gt 0 ] && [ $((now-T2)) -ge "$BS" ];then tier=2;[ "$ARM2" -eq 1 ] && { queue_notice HOT "高温警报：超过 $((B/1000))℃ 已持续 $((BS/60))分钟。$brief 请及时改善散热。";ARM2=0;logit 'ALERT_TIER_2'; };fi
    if [ "$T3" -gt 0 ] && [ $((now-T3)) -ge "$CS" ];then tier=3;[ "$ARM3" -eq 1 ] && { queue_notice CRITICAL "严重高温：超过 $((C/1000))℃ 已持续 $((CS/60))分钟。$brief 请移出背包并关注外接电池；此处不测量电芯温度。";ARM3=0;logit 'ALERT_TIER_3'; };fi
    held1=0;held2=0;held3=0
    [ "$T1" -eq 0 ] || held1=$((now-T1));[ "$T2" -eq 0 ] || held2=$((now-T2));[ "$T3" -eq 0 ] || held3=$((now-T3))
    printf 'OK|%s|%s|%s|%s|%s|%s\n' "$now" "$t" "$held1" "$held2" "$held3" "$tier" > "$REC"
    # Five-minute slope; reset baseline every 5 minutes, suppress repeat until temp stabilizes.
    [ "$RISE_AT" -gt 0 ] || { RISE_AT=$now;RISE_START=$t; }
    if [ $((now-RISE_AT)) -ge 300 ];then
      lim=$(cat "$RISE" 2>/dev/null);is_int "$lim" || lim=1000
      delta=$((t-RISE_START));span=$((now-RISE_AT))
      if [ "$delta" -ge $((lim*span/60)) ] && [ "$RISE_ARMED" -eq 1 ];then
        queue_notice RISING "升温过快：最近 $((span/60)) 分钟升高约 $((delta/1000))℃，当前 $((t/1000))℃；请检查通风。"
        RISE_ARMED=0;logit 'ALERT_FAST_RISE'
      fi
      [ "$delta" -le 0 ] && RISE_ARMED=1
      RISE_AT=$now;RISE_START=$t
    fi
    if [ $((now-LAST_SIG)) -ge 60 ];then
      LAST_SIG=$now;signal_probe
      if [ "$SIGNAL_RSRP" != NA ];then
        SGN=$((SGN+1));SGSUM=$((SGSUM+SIGNAL_RSRP))
        [ "$SIGNAL_SINR" = NA ] || { SINN=$((SINN+1));SINSUM=$((SINSUM+SIGNAL_SINR)); }
        [ "$SIGNAL_RSRP" -le -105 ] && WEAK=$((WEAK+1)) || STRONG=$((STRONG+1))
      fi
    fi
    if [ $((now-LAST_FLOW)) -ge 60 ];then
      LAST_FLOW=$now
      if flow_update;then FD=$FLOW_DAY;FM=$FLOW_MONTH;fi
    fi
    if [ $((now-LAST_STATS)) -ge 60 ];then LAST_STATS=$now;stats_save;report_daily;fi
    flush_notice
    sleep "$INTERVAL"
  done
}
start() {
  if valid_pid;then echo ALREADY_RUNNING;return 0;fi
  rm -f "$PID"
  nohup sh "$BIN" run </dev/null >/dev/null 2>&1 &
  sleep 1
  if valid_pid;then echo STARTED;else echo START_FAILED;return 1;fi
}
stop() {
  boot_off || true
  if valid_pid;then kill "$(cat "$PID")" 2>/dev/null;echo STOP_REQUESTED
  else rm -f "$PID";echo NOT_RUNNING;fi
}
probe_now() {
  # User-initiated refresh: native data direct read. Stale background sample files are not sufficient.
  t=$(read_temp 2>/dev/null);is_int "$t" || t=0
  if flow_update;then
    printf 'PROBE_FLOW=OK\n'
  else
    printf 'PROBE_FLOW=UNAVAILABLE\n'
  fi
  signal_probe
  if [ "$SIGNAL_RSRP" = NA ];then echo 'PROBE_SIGNAL=UNAVAILABLE';else echo 'PROBE_SIGNAL=OK';fi
  status
}
status() {
  echo VERSION=1.1.1
  led_status
  if [ -r "$REC" ];then
    IFS='|' read -r tag sample_ts remaining < "$REC"
    if is_int "$sample_ts" && [ "$sample_ts" -gt 0 ];then
      age=$(($(date +%s)-sample_ts))
      [ "$age" -ge 0 ] || age=-1
      echo "SAMPLE_AGE=$age"
    else echo SAMPLE_AGE=NA;fi
  else echo SAMPLE_AGE=NA;fi
  if valid_pid;then echo RUNNING=1;else echo RUNNING=0;fi
  printf 'ZONE=%s\nTHRESHOLDS=%s\n' "$(cat "$ZONE" 2>/dev/null)" "$(cat "$CFG" 2>/dev/null)"
  if [ -r "$REC" ];then cat "$REC";else echo NO_READING;fi
  if [ -f "$BOOT" ] && grep -Fq '# F50_ALERT_V6_START' "$BOOT";then echo BOOT=1;else echo BOOT=0;fi
  if [ -r "$FLOW" ];then
    read -r d m dev total db mb last < "$FLOW"
    printf 'FLOW=%s|%s|%s\n' "${db:-0}" "${mb:-0}" "$dev"
    echo "FLOW_DAY=$d";echo "FLOW_SOURCE=$dev"
    age=0;is_int "$last" && age=$(($(date +%s)-last))
    echo "FLOW_AGE=$age"
  else echo 'FLOW=NA';echo 'FLOW_SOURCE=UNAVAILABLE';fi
  [ -r "$FLOWRAW" ] && { IFS='|' read -r raw rts rsrc < "$FLOWRAW"; echo "FLOW_RAW=${raw:-NA}"; } || echo FLOW_RAW=NA
  [ -r "$FLOWQUALITY" ] && echo "FLOW_QUALITY=$(cat "$FLOWQUALITY")" || echo FLOW_QUALITY=NOT_STARTED
  [ -r "$FLOWSINCE" ] && echo "FLOW_SINCE=$(cat "$FLOWSINCE")" || echo FLOW_SINCE=0
  if [ -r "$SIGNAL" ];then printf 'SIGNAL=%s\n' "$(tail -n1 "$SIGNAL")";else echo SIGNAL=NA;fi
}
case "$1" in
 scan) scan;; read) read_temp;; run) run;; start) start;; stop) stop;; status) status;; selftest) selftest;;
 led_config) led_config "$2";; led_status) led_status;; led_cleanup) led_cleanup_legacy;;
 boot) boot_on && echo BOOT_ENABLED;;
 history) tail -n 3000 "$HISTORY" 2>/dev/null || true;;
 signals) tail -n 3000 "$SIGNAL" 2>/dev/null || true;;
 flow_history) tail -n 3000 "$FLOWHIST" 2>/dev/null || true;;
 diag) telemetry_diag;;
 probe_now) probe_now;;
 health) stats_summary "$STATS";echo YESTERDAY;stats_summary "$YDAY";;
 logs) tail -n 90 "$LOG" 2>/dev/null || true;;
 rules)
  [ "$#" -eq 7 ] || { echo BAD_ARGS;exit 1; }
  for x in "$2" "$3" "$4" "$5" "$6" "$7";do is_int "$x" || { echo BAD_NUM;exit 1; };done
  [ "$2" -ge 50 ] && [ "$6" -le 85 ] && [ "$2" -lt "$4" ] && [ "$4" -lt "$6" ] || { echo BAD_TEMPERATURE;exit 1; }
  for x in "$3" "$5" "$7";do [ "$x" -ge 1 ] && [ "$x" -le 60 ] || { echo BAD_DURATION;exit 1; };done
  printf '%s %s %s %s %s %s\n' "$(($2*1000))" "$(($3*60))" "$(($4*1000))" "$(($5*60))" "$(($6*1000))" "$(($7*60))" > "$CFG"
  echo RULES_SAVED;;
 zone)
  if valid_zone "$2";then echo "$2" > "$ZONE";echo ZONE_SAVED;else echo BAD_ZONE;exit 1;fi;;
 notify_status)
  [ "$(cat "$PUSH" 2>/dev/null)" = 1 ] && echo PUSH=ON || echo PUSH=OFF
  [ -s "$TOKEN" ] && echo TOKEN=SET || echo TOKEN=EMPTY
  [ -r "$QUEUE" ] && echo QUEUE="$(wc -l < "$QUEUE")" || echo QUEUE=0
  echo REPORT_HOUR="$(cat "$HOUR" 2>/dev/null)"
  echo REPORT_ON="$(cat "$DAILY" 2>/dev/null)"
  echo RISE_LIMIT="$(cat "$RISE" 2>/dev/null)"
  :;;
 notify_config)
  case "$2" in 0|1) :;; *) echo BAD_PUSH_MODE;exit 1;; esac
  tok=$3
  case "$tok" in KEEP) :;; CLEAR) : > "$TOKEN";; *)
   case "$tok" in ''|*[!A-Za-z0-9_-]*) echo INVALID_TOKEN;exit 1;; esac
   [ "${#tok}" -le 256 ] || { echo TOKEN_TOO_LONG;exit 1; }
   printf '%s' "$tok" > "$TOKEN";; esac
  chmod 600 "$TOKEN" 2>/dev/null || true
  [ "$2" = 0 ] || [ -s "$TOKEN" ] || { echo TOKEN_MISSING;exit 1; }
  echo "$2" > "$PUSH";echo PUSH_SAVED;;
 notify_test)
  if push_send 'F50 monitoring test' 'F50 alert-only monitoring PushPlus API test. Please verify WeChat receipt.';then echo API_ACCEPTED_DELIVERY_UNCONFIRMED;else echo PUSH_FAILED;exit 1;fi;;
 report_config)
  case "$2" in 0|1) :;; *) echo BAD_REPORT_MODE;exit 1;; esac
  case "$3" in 00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23) :;; *) echo BAD_HOUR;exit 1;; esac
  echo "$2" > "$DAILY";echo "$3" > "$HOUR";echo REPORT_SAVED;;
 report_now)
  msg=$(report_html "$STATS") || { echo NO_DATA;exit 1; }
  msg=$(printf '%s' "$msg" | tr '\n' ' ')
  if push_send 'F50 当前健康报告' "$msg" html;then echo API_ACCEPTED_DELIVERY_UNCONFIRMED;else echo PUSH_FAILED;exit 1;fi;;
 report_preview) report_html "$STATS";;
 rise)
  is_int "$2" && [ "$2" -ge 500 ] && [ "$2" -le 3000 ] || { echo BAD_RISE;exit 1; }
  echo "$2" > "$RISE";echo RISE_SAVED;;
 uninstall) stop;rm -rf "$BASE";echo REMOVED;;
 *) echo 'commands: start stop status read scan history signals health logs rules zone notify_config notify_test report_config report_now rise selftest boot uninstall';exit 2;;
esac
