#!/bin/bash
# ==============================================================================
#  ArkOS Ports - Clear internal eMMC  (QUICK / 快速清除)
#  参照 arkos_official_353_emmc_flash.sh 的图形化框架编写
#
#  快速清除策略：
#    1) blkdiscard  —— 让 eMMC 控制器快速丢弃全部数据块（若支持）
#    2) wipefs -a   —— 擦除分区表 / 文件系统签名
#    3) dd 清零前 16MB —— 彻底破坏引导程序与分区表
#  进度来源：dd 自带的 status=progress（不依赖 pv，掌机无需联网）
#  图形：全程单个 dialog --gauge 进度条，进度条上方实时显示阶段/百分比/速度/ETA
#        所有 dialog 统一输出到 /dev/tty1，与 ArkOS 内置 msgbox 完全同款风格
#
#  日志：/roms/ports/emmc_clear_quick.log（追加模式，目录不可写时回退 /tmp）
# ==============================================================================

export TERM=linux

TITLE="ArkOS - Clear eMMC (QUICK)"
TARGET="/dev/mmcblk0"
QUICK_BYTES=$((16 * 1024 * 1024))     # 16 MiB
START_EPOCH=$(date +%s)

# 日志文件优先放 /roms/ports（SD 卡上，拔卡可读）；不可写则回退 /tmp
LOG_DIR="/roms/ports"
if [ ! -d "$LOG_DIR" ] || ! touch "$LOG_DIR/.emmc_log_test" 2>/dev/null; then
  LOG_DIR="/tmp"
fi
rm -f "$LOG_DIR/.emmc_log_test" 2>/dev/null
LOG_FILE="$LOG_DIR/emmc_clear_quick.log"

# ------------------------------------------------------------------------------
# 日志函数：只写文件不写终端，避免干扰 dialog 画面
# ------------------------------------------------------------------------------
log() {
  local tag="$1"; shift
  printf '[%s] [%-7s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$tag" "$*" >> "$LOG_FILE" 2>/dev/null
}
{
  printf '\n============================================================\n'
  printf ' RUN START  %s   mode=QUICK   pid=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$"
  printf '============================================================\n'
} >> "$LOG_FILE" 2>/dev/null
log "INFO" "script=$0 user=$(whoami 2>/dev/null) uid=$(id -u)"
log "INFO" "kernel=$(uname -a 2>/dev/null)"
log "INFO" "target=$TARGET zero_bytes=$QUICK_BYTES log=$LOG_FILE"
[ "$LOG_DIR" != "/roms/ports" ] && log "WARN" "/roms/ports not writable - log fell back to $LOG_FILE"
trap 'RC_EXIT=$?; log "END" "script exit rc=$RC_EXIT"' EXIT
trap 'log "SIGNAL" "received SIGINT/SIGTERM - aborting"; exit 130' INT TERM

# ------------------------------------------------------------------------------
# 0. 基础命令与图形组件（掌机无网络：只检查，不尝试联网安装）
# ------------------------------------------------------------------------------
if ! command -v dialog >/dev/null 2>&1; then
  log "ABORT" "'dialog' not found (no network; cannot install)"
  echo "ERROR: 'dialog' is required but not found." >&2
  exit 1
fi
log "DEP" "dialog OK: $(command -v dialog)"

# ArkOS 内置 msgbox 的实现方式就是：
#   dialog --clear --msgbox "$1" H W 2>&1 > /dev/tty1
# 强制画到 /dev/tty1，这样从 EmulationStation 启动时图形框才会显示在屏幕上。
# 这里所有 dialog 调用都照此处理，保证与 msgbox 完全同款风格。
if ! command -v msgbox >/dev/null 2>&1; then
  msgbox() { dialog --clear --msgbox "$1" 12 72 2>&1 > /dev/tty1; }
fi
if ! command -v osk >/dev/null 2>&1; then
  osk() { dialog --inputbox "$1" 10 60 2>&1 > /dev/tty1; }
fi

require_bin() {
  bin="$1"
  if command -v "$bin" >/dev/null 2>&1; then
    log "DEP" "$bin OK: $(command -v "$bin")"
    return 0
  fi
  log "ABORT" "required binary '$bin' not found (device has no network; cannot install)"
  msgbox "Required tool '$bin' is missing and cannot be installed (no network). Please use an ArkOS build that includes it."
  exit 1
}
require_bin dd
require_bin awk
require_bin date
require_bin tr
require_bin blockdev

# 提权方式（直接用 sudo，和官方脚本一致）
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"
if [ -n "$SUDO" ] && ! command -v sudo >/dev/null 2>&1; then
  log "ABORT" "need root privileges but sudo not found"
  echo "ERROR: this tool needs root privileges (sudo not found)." >&2
  exit 1
fi
log "INFO" "privilege helper: ${SUDO:-direct-root}"

# ------------------------------------------------------------------------------
# 1. 安全检查
# ------------------------------------------------------------------------------
if [ ! -b "$TARGET" ]; then
  log "ABORT" "target block device $TARGET not found (no eMMC / DTB issue?)"
  msgbox "Cannot find $TARGET. This device seems to have no internal eMMC, or it is not accessible."
  exit 1
fi
log "CHECK" "target block device $TARGET present"

DTYPE=$(cat /sys/block/mmcblk0/device/type 2>/dev/null)
log "CHECK" "/sys/block/mmcblk0/device/type='${DTYPE:-<empty>}'"
if [ -n "$DTYPE" ] && [ "$DTYPE" != "MMC" ]; then
  log "ABORT" "device type is '$DTYPE', not MMC - refusing to continue"
  msgbox "SAFETY CHECK FAILED: $TARGET looks like a '$DTYPE' card, not an eMMC. Refusing to continue."
  exit 1
fi

for mp in / /boot; do
  SRC=$(df "$mp" 2>/dev/null | awk 'NR==2 {print $1}')
  log "CHECK" "mountpoint $mp -> ${SRC:-unknown}"
  case "$SRC" in
    *mmcblk0*)
      log "ABORT" "running ArkOS from the internal eMMC ($SRC on $mp)"
      msgbox "You appear to be running ArkOS FROM the internal eMMC. Please boot ArkOS from an SD card before running this tool."
      exit 1
      ;;
  esac
done

MOUNTS=$(mount 2>/dev/null | awk -v d="$TARGET" '$1 ~ "^" d {print $1}' | sort -u)
log "CHECK" "mounted eMMC partitions: ${MOUNTS:-none}"
if [ -n "$MOUNTS" ]; then
  # 自动卸载，不再弹 yesno（手柄按键会返回 255 导致误判取消）
  log "ACTION" "auto-unmounting mounted eMMC partitions (no dialog by request): ${MOUNTS//$'\n'/ }"
  for m in $MOUNTS; do
    $SUDO umount -f "$m" >>"$LOG_FILE" 2>&1
    log "ACTION" "umount -f $m rc=$?"
  done
  MOUNTS=$(mount 2>/dev/null | awk -v d="$TARGET" '$1 ~ "^" d {print $1}' | sort -u)
  log "CHECK" "mounted eMMC partitions after unmount: ${MOUNTS:-none}"
  if [ -n "$MOUNTS" ]; then
    log "ABORT" "eMMC partitions still mounted: $MOUNTS"
    msgbox "Some eMMC partitions are still mounted. Please unmount them manually and run this tool again."
    exit 1
  fi
fi

# 电量限制：20%（原为 60%）
if [ -r /sys/class/power_supply/battery/capacity ]; then
  CAP=$(cat /sys/class/power_supply/battery/capacity)
  log "CHECK" "battery capacity=${CAP:-unknown} (minimum 20%)"
  case "$CAP" in
    ''|*[!0-9]*) ;;
    *) if [ "$CAP" -lt 20 ]; then
         log "ABORT" "battery below 20% ($CAP%)"
         msgbox "Battery is below 20%. Please charge your device to at least 20% and run this tool again."
         exit 1
       fi ;;
  esac
else
  log "CHECK" "battery capacity sysfs not present - skipping battery check"
fi

# ------------------------------------------------------------------------------
# 2. 警告（msgbox 本身即确认：按 OK/START 就开始，不再弹额外确认框）
#    说明：掌机手柄在 dialog --yesno 上按键会返回 ESC(255)，导致直接 Cancelled，
#          故按要求去掉中间确认框，仅保留这一个 msgbox 作警示 + 确认。
# ------------------------------------------------------------------------------
log "UI" "showing WARNING msgbox (OK = confirm; no extra dialog by request)"
msgbox "WARNING - QUICK CLEAR OF INTERNAL EMMC\n\nThis will ERASE the internal eMMC ($TARGET):\n  - discard all data blocks (if supported)\n  - wipe the partition table and signatures\n  - zero out the first 16 MB (bootloader + partition table)\n\nAll data and any OS on the eMMC will be LOST. The device will no longer boot from eMMC until you flash a new image.\n\nDO NOT power off or stop this process once it starts.\n\nPress OK / START to begin NOW."
log "CONFIRM" "user pressed OK on warning msgbox - proceeding directly (no extra confirm by request)"

if command -v lsblk >/dev/null 2>&1; then
  INFO=$($SUDO lsblk -o NAME,SIZE,TYPE,MOUNTPOINT "$TARGET" 2>/dev/null)
  log "INFO" "lsblk snapshot of $TARGET follows:"
  printf '%s\n' "$INFO" | while IFS= read -r line; do log "INFO" "  $line"; done
else
  INFO="(lsblk not available)"
  log "INFO" "lsblk not available - skipping device snapshot"
fi

# ------------------------------------------------------------------------------
# 3. 进度显示：统一用一个 dialog --gauge，进度条上方显示实时状态
#    实时状态 = 当前阶段 + 百分比 + 已处理量/总量 + 速度 + 预计剩余时间(ETA)
#    dd 的 status=progress 输出形如:
#      8388608 bytes (8.4 MB, 8.0 MiB) copied, 0.016 s, 520 MB/s
# ------------------------------------------------------------------------------

# 字节数转成易读单位
human_bytes() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1073741824)   printf "%.2f GiB", b / 1073741824
    else if (b >= 1048576) printf "%.1f MiB", b / 1048576
    else if (b >= 1024)    printf "%.0f KiB", b / 1024
    else                   printf "%.0f B", b
  }'
}

# 输出一条 gauge 状态（百分比 + 上方单行文字）
emit_status() {
  local pct="$1" text="$2"
  printf 'XXX\n%d\n%s\nXXX\n' "$pct" "$text"
}

# 解析 dd 进度输出 → gauge 多行实时状态
#   $1=总字节数  $2=阶段标题  $3=进度起点  $4=进度跨度
progress_filter() {
  local total="$1" label="$2" base="${3:-0}" span="${4:-100}"
  local line bytes realpct pct now elapsed_ms stat speed eta wwritten
  local start
  start=$(date +%s%3N 2>/dev/null)
  case "$start" in ''|*[!0-9]*) start=$(( $(date +%s) * 1000 ));; esac
  speed="--"; eta="--:--"
  while IFS= read -r line; do
    case "$line" in
      *copied*) ;;
      *) [ -n "$line" ] && log "DDMSG" "$line"; continue ;;
    esac
    bytes=${line%% *}
    case "$bytes" in ''|*[!0-9]*) continue ;; esac
    realpct=$(( bytes * 100 / total ))
    [ "$realpct" -gt 100 ] && realpct=100
    pct=$(( base + realpct * span / 100 ))
    [ "$pct" -gt 100 ] && pct=100
    now=$(date +%s%3N 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=$(( $(date +%s) * 1000 ));; esac
    elapsed_ms=$((now - start))
    [ "$elapsed_ms" -lt 100 ] && elapsed_ms=100
    stat=$(awk -v b="$bytes" -v t="$total" -v m="$elapsed_ms" 'BEGIN {
      s = m / 1000
      rate = b / s
      if (rate >= 1073741824) sp = sprintf("%.2f GB/s", rate / 1073741824)
      else if (rate >= 1048576) sp = sprintf("%.1f MB/s", rate / 1048576)
      else if (rate >= 1024)    sp = sprintf("%.0f KB/s", rate / 1024)
      else                      sp = sprintf("%.0f B/s", rate)
      remain = t - b
      if (remain < 0) remain = 0
      if (b <= 0 || rate <= 0) { et = "--:--" }
      else {
        rem = remain / rate
        hh = int(rem / 3600); mm = int((rem % 3600) / 60); ss = int(rem % 60)
        et = sprintf("%02d:%02d:%02d", hh, mm, ss)
      }
      printf "%s|%s", sp, et
    }')
    speed=${stat%%|*}
    eta=${stat##*|}
    wwritten=$(human_bytes "$bytes")
    log "PROG" "stage=$label pct=$pct realpct=$realpct bytes=$bytes speed=$speed eta=$eta"
    printf 'XXX\n%d\n%s | %d%% | %s/%s | %s | ETA %s\nXXX\n' \
      "$pct" "$label" "$realpct" "$wwritten" "$WTOTAL" "$speed" "$eta"
  done
}

# ------------------------------------------------------------------------------
# 4. 执行快速清除：全程一个图形进度条，上方实时显示各阶段状态
#    不依赖 pv，掌机无需联网
# ------------------------------------------------------------------------------
log "ACTION" "starting quick clear (blkdiscard + wipefs + zero-fill first $QUICK_BYTES bytes of $TARGET)"
WTOTAL=$(human_bytes "$QUICK_BYTES")
RC_FILE="$LOG_DIR/.emmc_quick_ddrc"
rm -f "$RC_FILE"

# Quick 只有 16MB，dd 会瞬间完成、进度条一闪而过。
# 因此分 8 块写入，每块之间停 0.25s 让 dialog 逐帧重绘，形成可见的加载动画。
CHUNKS=8
CHUNK_BYTES=$(( QUICK_BYTES / CHUNKS ))

{
  emit_status 2 "Step 1/3  Discarding data blocks..."
  if command -v blkdiscard >/dev/null 2>&1; then
    $SUDO blkdiscard "$TARGET" >>"$LOG_FILE" 2>&1
    log "ACTION" "blkdiscard rc=$?"
  else
    log "ACTION" "blkdiscard not available - skipped"
  fi
  sleep 0.3

  emit_status 14 "Step 2/3  Wiping signatures..."
  if command -v wipefs >/dev/null 2>&1; then
    $SUDO wipefs -a "$TARGET" >>"$LOG_FILE" 2>&1
    log "ACTION" "wipefs -a rc=$?"
  else
    log "ACTION" "wipefs not available - skipped"
  fi
  sleep 0.3

  log "ACTION" "dd zero-fill start (chunked x$CHUNKS bs=1M, no pv, animated)"
  CH_RC=0
  i=1
  while [ "$i" -le "$CHUNKS" ]; do
    pct=$(( 20 + i * 80 / CHUNKS ))
    emit_status "$pct" "Step 3/3  Zero-fill $WTOTAL  ($i/$CHUNKS)"
    head -c "$CHUNK_BYTES" /dev/zero \
      | $SUDO dd of="$TARGET" bs=1M conv=fsync status=none 2>>"$LOG_FILE"
    PRC=("${PIPESTATUS[@]}")
    log "ACTION" "chunk $i/$CHUNKS rc: head=${PRC[0]} dd=${PRC[1]}"
    [ "${PRC[1]}" -ne 0 ] && CH_RC=${PRC[1]}
    i=$((i + 1))
    sleep 0.25
  done
  echo "$CH_RC" > "$RC_FILE"
  log "PROG" "zero-fill chunks done, pct=100 rc=$CH_RC"

  emit_status 100 "Done  Syncing to eMMC..."
  sleep 0.8
} | dialog --title "$TITLE" --gauge "Preparing..." 9 70 0 2>&1 > /dev/tty1

if [ -f "$RC_FILE" ]; then RC=$(cat "$RC_FILE"); rm -f "$RC_FILE"; else RC=1; fi
$SUDO sync
log "ACTION" "sync rc=$?"
DURATION=$(( $(date +%s) - START_EPOCH ))
log "RESULT" "erase finished rc=$RC duration=${DURATION}s"
log "INFO" "log file location: $LOG_FILE"

dialog --clear 2>&1 > /dev/tty1
if [ "$RC" -ne 0 ]; then
  log "RESULT" "FAILED (rc=$RC) - see earlier log lines for details"
  msgbox "FAILED: an error occurred while clearing the eMMC (exit code $RC). Please run the tool again.\n\nLog file: $LOG_FILE"
  exit 1
fi
log "RESULT" "SUCCESS - internal eMMC quick-cleared"
msgbox "DONE. The internal eMMC has been quick-cleared.\n\nThe partition table, bootloader and signatures are gone; the device can no longer boot from eMMC until you flash a new image.\n\nYou can now reboot and use the official ArkOS eMMC flash tool to write a new image.\n\nLog file: $LOG_FILE"
