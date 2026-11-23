# ARKOS / ROCKNIX eMMC Clean

**中文** | [English](#english)

掌机内置 eMMC 清除工具集，覆盖两套主流系统，共四个脚本。全部以 **Ports 可视化脚本**形式提供——直接从 EmulationStation 的 Ports 菜单启动，无需键盘、无需命令行，全程图形界面 + 实时进度条。

两套系统底层图形栈不同，因此脚本实现也不同，请按你的系统选择对应脚本：

| 系统 | 图形实现 | 脚本前缀 |
|---|---|---|
| **ArkOS / DarkOS** | `dialog --gauge`（framebuffer / tty1） | `arkos-` |
| **AURKNIX / ROCKNIX** | mpv 全屏 + Lua OSD（Wayland） | `aurknix-` |

> ⚠️ 两套脚本**不可混用**：`arkos-` 系列依赖 `dialog` 且输出到 `/dev/tty1`，适用于 ArkOS/DarkOS；`aurknix-` 系列依赖 `mpv` + Wayland，适用于 AURKNIX/ROCKNIX。

## 脚本一览

### ArkOS / DarkOS（`dialog` 版）

| 文件 | 作用 |
|---|---|
| `arkos-emmc-clear-quick.sh` | **快速清除**：blkdiscard 丢弃数据块 → wipefs 擦除签名 → 分块清零前 16 MiB（引导区 + 分区表）。速度快 |
| `arkos-emmc-clear-full.sh` | **完全清除**：逐块写零覆盖整块 eMMC，彻底但耗时 |

确认方式：弹出一个警示 msgbox，按 **OK / START** 即开始（已去掉二次确认框——手柄在 `dialog --yesno` 上按键会返回 ESC 导致误判取消）。

### AURKNIX / ROCKNIX（mpv OSD 版）

| 文件 | 作用 |
|---|---|
| `aurknix-emmc-format-quick.sh` | **快速清除**：丢弃数据块 + 擦除签名 + 清零前 16 MiB |
| `aurknix-emmc-format-full.sh` | **完全清除**：逐块写零覆盖整块 eMMC |

界面显示标题、实时进度条、百分比、传输速度、ETA；背景图已内嵌，OSD 按屏幕分辨率等比缩放并居中。

## 使用方法

### 安装到掌机

把对应平台的脚本复制到掌机的 `ports` 目录，并确保有可执行权限（从 U 盘复制后通常需要）：

```sh
# ArkOS / DarkOS
chmod +x /roms/ports/arkos-emmc-*.sh

# AURKNIX / ROCKNIX
chmod +x /storage/roms/ports/aurknix-emmc-*.sh
```

然后在 EmulationStation 的 **Ports** 菜单里刷新并启动。

### 取消操作

格式化默认会持续到完成。如需中途取消：

- **AURKNIX / ROCKNIX**：按住手柄 **B 键超过 5 秒**（键盘备用 `b`）。松开立即归零重新计时，正好 5 秒不触发；屏幕底部正中显示 `HOLD B > 5s TO CANCEL`
- **ArkOS / DarkOS**：进度启动后不提供手柄中途取消（手柄按键会干扰 `dialog`）；如需中止请在确认框出现前退出

> ⚠️ 中途取消会中止写入，eMMC 可能处于**部分擦除**状态，需重新完整格式化后才能装机。

## 日志

- **ArkOS**：`/roms/ports/emmc_clear_quick.log`、`/roms/ports/emmc_clear_full.log`（不可写时回退 `/tmp`）
- **AURKNIX**：`/tmp/format_emmc_quick.log`、`/tmp/format_emmc_full.log`

末尾会追加一条汇总（总用时 + 平均速度）：

```
[SUMMARY] total bytes: 32.00 GiB | elapsed: 00:03:25 | average speed: 159.8 MB/s
```

## 安全设计

- 固定目标为内置 eMMC `/dev/mmcblk0`，并校验设备类型——识别出是 SD 卡则拒绝执行
- 拒绝从 eMMC 自身启动时运行（避免擦掉正在用的系统）
- 电量低于 **20%** 时拒绝格式化，防止写入中途断电变砖
- 操作前卸载所有 eMMC 分区，完成后 `sync` 刷新缓冲
- 全程提示 `DO NOT power off`
- 完全格式化采用分块写零 + 自计数进度，不依赖 `/proc/PID/io`（真机 BusyBox 上该值恒为 0，会导致进度卡死）

## 兼容性

**ArkOS / DarkOS**
- 依赖 `dialog`（脚本内已处理无网络情况下的依赖检查）
- 所有图形输出到 `/dev/tty1`，与系统内置 msgbox 同款风格

**AURKNIX / ROCKNIX**
- 依赖 `mpv` 与 Wayland 图形环境，脚本已带 `--input-gamepad=yes`
- 内嵌背景图为 JPEG，运行时解压到 `/tmp/emmc_bg.jpg`
- OSD 以 640×480 为基准按实际屏幕等比缩放
- 提供键盘备用键位，无手柄也可操作

## 免责声明

这些脚本会**不可逆地清除内置 eMMC 上的全部数据**。请自行确认目标设备、备份重要资料并确保电量充足。使用风险由使用者自行承担。

---

<a name="english"></a>

## English

eMMC clearing tools for handheld consoles, covering two major firmware families in four scripts. All are delivered as **visual Ports scripts** — launch directly from the EmulationStation Ports menu, no keyboard or command line required, with a full graphical interface and live progress bar.

The two firmware families use different graphics stacks, so the scripts differ. Pick the ones matching your system:

| Firmware | Graphics implementation | Script prefix |
|---|---|---|
| **ArkOS / DarkOS** | `dialog --gauge` (framebuffer / tty1) | `arkos-` |
| **AURKNIX / ROCKNIX** | mpv fullscreen + Lua OSD (Wayland) | `aurknix-` |

> ⚠️ The two sets are **not interchangeable**. The `arkos-` scripts require `dialog` and draw to `/dev/tty1`; the `aurknix-` scripts require `mpv` + Wayland.

### Scripts

**ArkOS / DarkOS** (`dialog`)

| File | Purpose |
|---|---|
| `arkos-emmc-clear-quick.sh` | **Quick clear** — blkdiscard, wipe signatures, chunked zero-fill of the first 16 MiB (bootloader + partition table). Fast. |
| `arkos-emmc-clear-full.sh` | **Full clear** — zero-fill the entire eMMC block by block. Thorough but slow. |

A single warning msgbox is shown — press **OK / START** to begin (no extra confirmation dialog: gamepad buttons return ESC on `dialog --yesno`, which was misread as cancel).

**AURKNIX / ROCKNIX** (mpv OSD)

| File | Purpose |
|---|---|
| `aurknix-emmc-format-quick.sh` | **Quick clear** — discard blocks, wipe signatures, zero-fill first 16 MiB. |
| `aurknix-emmc-format-full.sh` | **Full clear** — zero-fill the entire eMMC. |

The UI shows title, live progress bar, percentage, speed and ETA. The background image is embedded and the OSD scales proportionally and stays centered.

### Usage

**Install**

Copy the scripts for your platform into the handheld's `ports` directory and make them executable:

```sh
# ArkOS / DarkOS
chmod +x /roms/ports/arkos-emmc-*.sh

# AURKNIX / ROCKNIX
chmod +x /storage/roms/ports/aurknix-emmc-*.sh
```

Then refresh and launch from the **Ports** menu in EmulationStation.

**Cancel**

- **AURKNIX / ROCKNIX**: hold gamepad **B for more than 5 seconds** (keyboard fallback: `b`). Releasing resets the timer; exactly 5 seconds will not trigger. A hint is pinned at bottom center: `HOLD B > 5s TO CANCEL`
- **ArkOS / DarkOS**: no mid-run gamepad cancel (gamepad input interferes with `dialog`); exit before the confirmation box if you need to abort

> ⚠️ Cancelling may leave the eMMC **partially erased** — re-run a full format before installing an OS.

### Logs

- **ArkOS**: `/roms/ports/emmc_clear_quick.log`, `/roms/ports/emmc_clear_full.log` (fall back to `/tmp` if not writable)
- **AURKNIX**: `/tmp/format_emmc_quick.log`, `/tmp/format_emmc_full.log`

Each run appends one summary line:

```
[SUMMARY] total bytes: 32.00 GiB | elapsed: 00:03:25 | average speed: 159.8 MB/s
```

### Safety

- Target is fixed to the internal eMMC `/dev/mmcblk0`, with device-type validation — refuses if the target looks like an SD card
- Refuses to run when booted from the eMMC itself
- Refuses to format below **20%** battery, avoiding a brick from mid-write power loss
- Unmounts all eMMC partitions before writing, and runs `sync` on completion
- Shows `DO NOT power off` throughout
- Full format uses chunked zero-fill with self-counted progress, avoiding `/proc/PID/io` (which reads as 0 on real BusyBox devices and freezes the progress bar)

### Compatibility

**ArkOS / DarkOS**
- Requires `dialog` (dependency checked at runtime; scripts handle the no-network case)
- All graphics draw to `/dev/tty1`, matching the system's built-in msgbox style

**AURKNIX / ROCKNIX**
- Requires `mpv` and Wayland; scripts pass `--input-gamepad=yes`
- Embedded JPEG background is extracted to `/tmp/emmc_bg.jpg` at runtime
- OSD uses a 640×480 base canvas scaled to the actual screen resolution
- Keyboard fallback keys are provided, so a gamepad is not strictly required

### Disclaimer

These scripts **irreversibly erase all data on the internal eMMC**. Verify the target device, back up important data, and ensure sufficient battery before use. Use at your own risk.
