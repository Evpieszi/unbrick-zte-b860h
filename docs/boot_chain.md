# Amlogic Boot Chain

## Overview

The Amlogic GXL P212 boot chain is:

```
ROM (in SoC) → TPL → U-Boot → Kernel → OS
```

### 1. ROM (Read-Only Memory)

- Built into the SoC
- Initializes basic hardware (clocks, power)
- Enters WorldCup USB-ROM mode if no valid boot is found
- In WorldCup mode, exposes a USB gadget for the host to communicate with

### 2. TPL (Third Party Loader)

- Loaded from ROM into SRAM
- Initializes DDR (using DDR init blob)
- Loads U-Boot from storage (eMMC, SD card, or USB)
- If `CONFIG_AML_CRYPTO_UBOOT` is set, decrypts U-Boot
- Jumps to U-Boot entry point

**Known TPL addresses:**
- DDR load/run: `0xd9000000`
- U-Boot load: `0x200c000` (current, possibly wrong)
- U-Boot TEXT_BASE: `0x01000000` (GXL ISABASE)
- bl2ParaAddr: `0xd900c000`
- Encrypt register: `0xc8100228`

### 3. U-Boot

- Initializes eMMC (`mmc dev`)
- Initializes USB serial (for `bulkcmd` communication)
- Loads and verifies kernel
- Loads and verifies DTB (Device Tree Blob)
- Hands off to kernel

**Board config flags (from `board_amlogic_configs_gxl_p212_v1.h`):**
- `CONFIG_AML_SD_EMMC 1` — eMMC enabled
- `CONFIG_USB_GADGET 1` — USB gadget enabled
- `CONFIG_USBDOWNLOAD_GADGET 1` — USB download gadget
- `CONFIG_AML_SECURE_UBOOT 1` — Secure boot enabled
- `CONFIG_AML_CRYPTO_UBOOT 1` — U-Boot is encrypted
- `CONFIG_SECURE_STORAGE 1` — Secure storage enabled
- `CONFIG_MULTI_DTB 1` — Multiple DTB support
- `CONFIG_FIP_IMG_SUPPORT 1` — FIP image support
- `CONFIG_NEED_BL301 1` — Needs BL301 (ARM Trusted Firmware)
- `CONFIG_NEED_BL32 1` — Needs BL32 (ARM Trusted Firmware)
- `CONFIG_EFUSE 1` — eFuse support

### 4. Kernel

- Linux kernel
- Loads DTB for hardware initialization
- Mounts root filesystem
- Starts init

### 5. OS

- Android (based on partition layout)
- Pulpstone firmware (3 partitions: boot, logo, system)

## Pulpstone Partition Layout

| Partition | Size | Address | Contents |
|-----------|------|---------|----------|
| boot | 9.6 MB | 0x1000000 | kernel (7MB @ 0x1080000) + ramdisk (2.4MB @ 0x1000000) + second (120KB @ 0xf00000) |
| logo | 160 KB | 0x19C0000 | Boot logo images |
| system | 1.8 GB | 0x1A00000 | ext4 root filesystem |

**Boot image magic**: `ANDROID!`

### Boot Flow (Normal)

```
Power ON
  → ROM initializes
  → TPL loads DDR init blob
  → DDR initialized
  → TPL loads U-Boot from eMMC
  → U-Boot decrypts (if encrypted)
  → U-Boot initializes eMMC
  → U-Boot loads kernel + DTB
  → U-Boot verifies signatures (secure boot)
  → Kernel boots
  → OS starts
```

### Boot Flow (WorldCup / Recovery)

```
Power ON
  → ROM initializes
  → ROM enters WorldCup USB-ROM mode
  → Host detects WorldCup Device
  → Host writes DDR init blob to RAM (0xd9000000)
  → Host runs DDR init blob
  → DDR initialized
  → Host writes U-Boot to RAM
  → Host runs U-Boot
  → U-Boot should initialize eMMC + USB serial
  → (Currently failing here)
```
