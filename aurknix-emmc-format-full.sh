#!/usr/bin/bash
# AURKNIX / ROCKNIX eMMC Format - FULL  (ArkOS-style dynamic progress)
# 内嵌背景图 + mpv OSD 动态进度，OSD 按屏幕分辨率等比缩放；分块写零自计数进度（真机 BusyBox 的 /proc/PID/io 恒为 0，导致进度卡死）
# 正常运行日志固定写到 /tmp（按键调试日志已移除）
LOG=/tmp/format_emmc_full.log
exec > >(tee -a "$LOG") 2>&1
echo "[INFO] log file: $LOG"
echo "============================================"
echo " Script started at $(date)  [FULL]"
echo "============================================"
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
export WAYLAND_DISPLAY=wayland-1
export DISPLAY=:0.0

echo "[INFO] Extracting embedded background image..."
BG_IMG=/tmp/emmc_bg.jpg
echo "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AQIRAxEAAACfAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB/9oACAECAAEFABYf/9oACAEDAAEFABYf/9oACAEBAAEFAIsD/9oACAECAgY/ABYf/9oACAEDAgY/ABYf/9oACAEBAQY/ABYH/9k=" | base64 -d > "$BG_IMG" 2>/dev/null || true
if [ ! -s "$BG_IMG" ]; then
  echo "[ERROR] failed to extract background image - OSD may not display"
else
  echo "[INFO] background image ready ($BG_IMG)"
fi

# ---------- mpv OSD 动态进度界面（Lua 定时器读进度文件，640x480 固定画布，无需图片/socat/nc/python） ----------
PROG=/tmp/emmc_progress.txt
OSD_LUA=/tmp/emmc_osd.lua
cat > "$OSD_LUA" <<'LUAEOF'
local progfile = "/tmp/emmc_progress.txt"
local cancelfile = "/tmp/emmc_cancel"
local cancelling = false
local HOLD_SEC = 5.0        -- 长按 B 键超过 5 秒才取消（正好 5 秒不触发）
local TICK = 0.12           -- 定时器间隔(秒)
local tick = 0
local b_active = false
local hold_ticks = 0

local function esc(s)
  return (tostring(s):gsub("\\", "/"):gsub("{", "("):gsub("}", ")"))
end

-- 以 640x480 为基准，按实际屏幕(OSD)分辨率等比缩放字号与位置
local function metrics()
  local W = mp.get_property_number("osd-width") or 640
  local H = mp.get_property_number("osd-height") or 480
  if W < 160 then W = 640 end
  if H < 120 then H = 480 end
  local scale = math.min(W / 640, H / 480)
  return W, H, scale, math.floor(W / 2), math.floor(H * 0.5)
end

local function trigger_cancel()
  if cancelling then return end
  cancelling = true
  local f = io.open(cancelfile, "w")
  if f then f:write("cancel\n"); f:close() end
end

-- complex binding 捕获 down/up/press/repeat；兼容新旧 mpv(回调参数 string 或 table)
-- down/press/repeat = 按住；up/cancel = 松开。单键长按不依赖组合键，规避手柄只报一个键的限制。
local function evname(e)
  if type(e) == "table" then return e.event end
  return e
end
local function on_b(e)
  if cancelling then return end
  local ev = evname(e) or "press"
  local active = not (ev == "up" or ev == "cancel")
  b_active = active
  if not active then hold_ticks = 0 end
end
mp.add_key_binding("GAMEPAD_ACTION_RIGHT", "cxl_b",  on_b, {complex = true})  -- B 键(真机已验证)
mp.add_key_binding("b",                   "cxl_kb", on_b, {complex = true})  -- 键盘备用

mp.add_periodic_timer(TICK, function()
  tick = tick + 1
  local W, H, sc, cx, cy = metrics()

  -- 按住 B 键累加；松开立即归零；严格超过 5 秒才触发(正好5s不触发)
  if b_active then
    hold_ticks = hold_ticks + 1
    if hold_ticks * TICK > HOLD_SEC then trigger_cancel() end
  else
    hold_ticks = 0
  end

  if cancelling then
    local ass = "{\\an5\\pos(" .. cx .. "," .. cy .. ")\\fs" .. math.floor(28 * sc) ..
                "\\b1\\c&H0000FF&\\bord2\\3c&H000000&}CANCELLED" ..
                "\\N{\\fs" .. math.floor(17 * sc) .. "\\c&HFFFFFF&\\bord2}stopping safely - DO NOT power off"
    mp.set_osd_ass(W, H, ass)
    return
  end

  local f = io.open(progfile, "r")
  if not f then return end
  local s = f:read("*a")
  f:close()
  if not s or s == "" then return end
  local a, b, c = s:match("([^\n]*)\n([^\n]*)\n(.*)")
  if not a then a, b, c = s, "", "" end
  local f1 = math.floor(30 * sc)
  local f2 = math.floor(24 * sc)
  local f3 = math.floor(18 * sc)
  -- 主内容块：垂直居中（cy）
  local ass = "{\\an5\\pos(" .. cx .. "," .. cy .. ")\\fs" .. f1 ..
              "\\b1\\c&H00FFFF&\\bord2\\3c&H000000&}" .. esc(a)
  if b ~= "" then ass = ass .. "\\N{\\fs" .. f2 .. "\\b0\\c&H00FF00&\\bord2\\3c&H000000&}" .. esc(b) end
  if c ~= "" then ass = ass .. "\\N{\\fs" .. f3 .. "\\c&HFFFFFF&\\bord2\\3c&H000000&}" .. esc(c) end
  -- 提示行：独立 \pos 锚点，放到屏幕靠近底部正中间（与 DSI 菜单每行独立 \pos 同理，已验证可行）
  local hintY = math.floor(H * 0.86)
  local hs = string.format("%.1f", hold_ticks * TICK)
  local col = b_active and "&HFF8040&" or "&H808080&"
  local state = b_active and ("HOLDING " .. hs .. "s") or "press to cancel"
  local hint = "HOLD B > 5s TO CANCEL  [" .. state .. "]"
  ass = ass .. "\\N{\\an5\\pos(" .. cx .. "," .. hintY .. ")\\fs" ..
        math.floor(14 * sc) .. "\\c" .. col .. "\\bord1}" .. hint
  mp.set_osd_ass(W, H, ass)
end)

LUAEOF
: > "$PROG"

set_progress() { printf '%s\n%s\n%s\n' "$1" "$2" "$3" > "$PROG"; }

# 取消标志：Lua 检测 B 键长按超过 5s 后写入，shell 进度循环读取后中止
CANCEL=/tmp/emmc_cancel
rm -f "$CANCEL" 2>/dev/null


# ---------- 安全检查：电量 <20% 拒绝（防止写入中途断电变砖） ----------
check_battery() {
  local cap="" p
  for p in /sys/class/power_supply/*/capacity /sys/class/power_supply/battery/capacity; do
    [ -r "$p" ] || continue
    cap=$(cat "$p" 2>/dev/null)
    case "$cap" in ''|*[!0-9]*) continue ;; esac
    break
  done
  case "$cap" in
    ''|*[!0-9]*) echo "[WARN] battery level unavailable - skipping check" ; return 0 ;;
  esac
  echo "[INFO] battery level: ${cap}%"
  if [ "$cap" -lt 20 ]; then
    echo "[ERROR] battery below 20% (${cap}%) - please charge first"
    set_progress "LOW BATTERY - ${cap}%" "Please charge above 20%" "No changes made"
    return 1
  fi
  return 0
}


# 全屏播放内嵌背景图 + OSD；一次启动，全程不重启（无 idle 提示、无闪烁）
start_display() {
  killall -9 mpv 2>/dev/null
  sleep 0.3
  mpv --input-gamepad=yes --loop-file=inf --fullscreen --no-terminal --no-osc \
      --keepaspect=yes --osd-font-size=24 --script="$OSD_LUA" \
      "$BG_IMG" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  sleep 1
}
progress_bar() {
  local pct="$1" width="${2:-16}" filled i bar=""
  filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled="$width"
  i=0
  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$filled" ]; then bar="${bar}#"; else bar="${bar}-"; fi
    i=$((i + 1))
  done
  printf '%s' "$bar"
}

cleanup_on_error() {
  echo ""; echo "[ERROR] FAILED! Check log: $LOG"
  set_progress "FAILED - eMMC format error" "[$(progress_bar 100)] ERROR" "see $LOG"
  sleep 15
  killall -9 mpv 2>/dev/null
}


human_bytes() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1073741824)   printf "%.2f GiB", b / 1073741824
    else if (b >= 1048576) printf "%.1f MiB", b / 1048576
    else if (b >= 1024)    printf "%.0f KiB", b / 1024
    else                   printf "%.0f B", b
  }'
}
fmt_eta() {
  local s="$1"
  printf '%02d:%02d:%02d' "$((s / 3600))" "$(((s % 3600) / 60))" "$((s % 60))"
}
fmt_speed() {
  awk -v r="$1" 'BEGIN {
    if (r >= 1048576) printf "%.1f MB/s", r / 1048576
    else if (r >= 1024) printf "%.0f KB/s", r / 1024
    else printf "%.0f B/s", r
  }'
}

# 结束时输出一条汇总：总用时 + 平均速度（用累计字节/累计秒，反映整段写入）
log_summary() {
  local bytes="$1" start="$2" end el avg
  end=$(date +%s)
  el=$((end - start)); [ "$el" -lt 1 ] && el=1
  avg=$((bytes / el))
  echo "[SUMMARY] total bytes: $(human_bytes "$bytes") | elapsed: $(fmt_eta "$el") | average speed: $(fmt_speed "$avg")"
}


# ---------- 主流程 ----------
echo "[INFO] Full Format starting..."
start_display
set_progress "FULL ERASE - Internal eMMC" "Preparing..." "DO NOT power off"
check_battery || { sleep 8; killall -9 mpv 2>/dev/null; exit 1; }

EMMC_DISK=/dev/mmcblk0
if [ ! -b "$EMMC_DISK" ]; then
  echo "[ERROR] eMMC not found at $EMMC_DISK"
  cleanup_on_error; exit 1
fi
echo "[INFO] eMMC detected"

echo "[INFO] Unmounting all partitions..."
for part in ${EMMC_DISK}*; do umount "$part" 2>/dev/null || true; done

SIZE=$(cat /sys/block/$(basename "$EMMC_DISK")/size 2>/dev/null)
case "$SIZE" in ''|*[!0-9]*)
  echo "[ERROR] cannot determine eMMC size"; cleanup_on_error; exit 1 ;;
esac
TOTAL=$((SIZE * 512)); WTOTAL=$(human_bytes "$TOTAL")
echo "[INFO] eMMC size: $WTOTAL ($TOTAL bytes)"
echo "[INFO] Overwriting entire eMMC with zeros (SLOW). DO NOT POWER OFF!"

# 分块写零 + 自计数进度：不读 /proc/PID/io（真机 BusyBox 上 wchar/write_bytes 恒为 0，进度会一直卡 0%）
DDERR=/tmp/emmc_dd.err
BLK_MB=8
BLK_BYTES=$((BLK_MB * 1048576))
BLOCKS=$(( (TOTAL + BLK_BYTES - 1) / BLK_BYTES ))
i=0; CANCELLED=0; FAILED=0
START=$(date +%s)
# 毫秒时间戳（BusyBox 不支持 %N 时回退到秒级*1000）
now_ms() {
  local t
  t=$(date +%s%3N 2>/dev/null)
  case "$t" in ''|*[!0-9]*) t=$(( $(date +%s) * 1000 )) ;; esac
  printf '%s' "$t"
}
# 滑动窗口速度：环形保存最近 SPD_WIN 块的(时间,字节)，用最近增量算瞬时速度，比累计平均灵敏
SPD_WIN=6
START_MS=$(now_ms)
for _s in 0 1 2 3 4 5; do eval "WT$_s=$START_MS"; eval "WB$_s=0"; done
echo "[INFO] zero-filling $TOTAL bytes in $BLOCKS blocks of ${BLK_MB}MiB"
set_progress "FULL ERASE - $WTOTAL" "[$(progress_bar 0)]   0%" "zero-fill ${BLOCKS} blocks"
while [ "$i" -lt "$BLOCKS" ]; do
  if [ -e "$CANCEL" ]; then
    echo "[WARN] cancel requested (B key held > 5s) - stopping"
    CANCELLED=1; break
  fi
  dd if=/dev/zero of="$EMMC_DISK" bs=1M count=$BLK_MB seek=$((i * BLK_MB)) \
     conv=notrunc 2>"$DDERR"
  RC=$?
  # 写满设备尾部时 dd 会报 "No space left" —— 属正常完成
  if [ "$RC" -ne 0 ] && ! grep -qi "no space left" "$DDERR"; then
    echo "[ERROR] dd failed at block $((i + 1))/$BLOCKS rc=$RC: $(cat "$DDERR")"
    FAILED=1; break
  fi
  i=$((i + 1))
  WRITTEN=$((i * BLK_BYTES))
  [ "$WRITTEN" -gt "$TOTAL" ] && WRITTEN=$TOTAL
  pct=$((WRITTEN * 100 / TOTAL))
  [ "$pct" -gt 100 ] && pct=100
  NOW_MS=$(now_ms)
  _slot=$((i % SPD_WIN))
  eval "WT$_slot=$NOW_MS"; eval "WB$_slot=$WRITTEN"
  _old=$(( (i + 1) % SPD_WIN ))
  eval "OT=\$WT$_old" 2>/dev/null; eval "OB=\$WB$_old" 2>/dev/null
  case "$OT" in ''|*[!0-9]*) OT=$START_MS ;; esac
  case "$OB" in ''|*[!0-9]*) OB=0 ;; esac
  _dt=$((NOW_MS - OT)); [ "$_dt" -lt 50 ] && _dt=50
  _dw=$((WRITTEN - OB)); [ "$_dw" -lt 0 ] && _dw=0
  SPD=$((_dw * 1000 / _dt))
  REM=$((TOTAL - WRITTEN)); [ "$REM" -lt 0 ] && REM=0
  if [ "$SPD" -gt 0 ]; then ETA=$((REM / SPD)); else ETA=0; fi
  set_progress "FULL ERASE - $WTOTAL" \
    "[$(progress_bar $pct)] ${pct}%  $(human_bytes "$WRITTEN")/$WTOTAL" \
    "$(fmt_speed "$SPD")   ETA $(fmt_eta "$ETA")"
  sleep 0.1
done

if [ "$CANCELLED" -eq 1 ]; then
  echo "[DONE] Cancelled by user - eMMC may be partially erased"
  sync
  set_progress "CANCELLED BY USER" "eMMC partially erased" "re-run format to complete"
  sleep 6
  killall -9 mpv 2>/dev/null
  exit 3
fi
if [ "$FAILED" -eq 1 ]; then
  cleanup_on_error; exit 1
fi
echo "[INFO] Zero fill completed ($i blocks)"

echo "[INFO] Flushing buffers (sync)..."
sync
partprobe "$EMMC_DISK" 2>/dev/null || true
echo "[DONE] Full format complete!"
log_summary "$TOTAL" "$START"

set_progress "DONE - eMMC fully erased" "[$(progress_bar 100)] 100%" "log: $LOG"
sleep 6
killall -9 mpv 2>/dev/null
