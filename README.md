# Unbrick ZTE B860H v1 STB

Recovery project for a soft-bricked **ZTE B860H v1** set-top box (STB) manufactured by **PT Adi Reka Mandiri**.

## Device Specs

| Component | Details |
|-----------|---------|
| SoC | Amlogic S905X / GXL P212 |
| RAM | 1 GB DDR |
| Storage | 8 GB eMMC |
| USB | USB 2.0 (rear, motherboard) |
| Power | 12V 2A adapter |
| Recovery mode | WorldCup (auto-enters on power) |
| USB Device ID | VID_1B8E & PID_C003 |

## Problem

The STB is soft-bricked: it powers on but never boots to the OS. The eMMC is not being initialized by U-Boot. The device auto-enters **WorldCup USB-ROM mode** on power (no reset button needed).

## Status

**In progress.** DDR and U-Boot blobs load and run via `update.exe`, but U-Boot never initializes eMMC or USB serial. All three U-Boot variants (Pulpstone, Brick_thru, AML) fail identically.

### Key findings

- `CONFIG_AML_SECURE_UBOOT 1` + `CONFIG_AML_CRYPTO_UBOOT 1` in board config — U-Boot is **encrypted** and **secure-boot verified**
- U-Boot load address should be **0x01000000** (GXL TEXT_BASE / ISABASE), not 0x200c000
- 32 KB is the reliable chunk size for USB writes (64 KB ~50% success, 68 KB+ fails)
- `UsbRomDrv.dll` has corrupted PE export table (ordinal-only exports) — CLI approach bypasses this

## Repository Structure

```
unbrick-zte-b860h/
├── README.md
├── .gitignore
├── docs/
│   ├── device_info.md          # Hardware specs & device identity
│   ├── boot_chain.md           # Amlogic boot chain explanation
│   ├── findings.md             # Technical findings & analysis
│   └── troubleshooting.md      # Known issues & workarounds
├── tools/
│   ├── update.exe              # Amlogic USB ROM CLI v0.8.1
│   ├── libusb0.dll             # USB library
│   ├── UsbRomDrv.dll           # USB ROM driver
│   ├── WorldCup_Device/        # Driver package (install this first)
│   └── scripts/
│       ├── unbrick.ps1         # Main unbrick script (32K chunked writes)
│       ├── test_uboot_addr.ps1 # Test U-Boot at 0x01000000
│       └── test_boot_cmd.ps1   # Test 'boot' command
├── firmware/
│   ├── brick_thru/             # Brick_thru package (DDR + U-Boot + partitions)
│   ├── aml_upgrade_package/    # AML upgrade package (alt DDR + partitions)
│   ├── pulpstone/              # Pulpstone-specific (usb_spl.bin + u-boot.bin)
│   └── pure_khadas_vim1/       # Pure Khadas VIM1 package
├── research/
│   ├── board_amlogic_configs_gxl_p212_v1.h  # Board config headers
│   ├── gxl_regs.h                          # GXL register definitions
│   ├── uboot_tree.json                     # U-Boot source tree (Khadas fork)
│   └── drivers_usb_gadget_aml_tiny_usbtool_*  # TPL USB boot source
├── analysis/
│   ├── disasm_full.txt         # Full disassembly of update.exe
│   ├── update_disasm.txt       # Targeted disassembly
│   ├── callsites.json          # Call site analysis
│   └── func_*.txt              # Individual function disassembly
└── ubt/
    └── USB_Burning_Tool v2.1.6  # Amlogic USB Burning Tool (GUI)
```

## Quick Start

### 1. Install the WorldCup driver

```
cd tools/WorldCup_Device
InstallDriver.exe
```

### 2. Verify the device

```
tools/update.exe identify
```

Expected output:
```
AmlUsbIdentifyHost
This firmware version is 2-2-0-0
```

If you get `ret=-116`, power cycle the STB (unplug USB + power, wait 10s, replug).

### 3. Run the unbrick script

```
powershell -File tools/scripts/unbrick.ps1
```

This will:
1. Write DDR init blob in 32 KB chunks to 0xd9000000
2. Run DDR
3. Write U-Boot in 32 KB chunks to 0x200c000
4. Run U-Boot
5. Verify with `msdev`

### 4. Test alternate U-Boot address

```
powershell -File tools/scripts/test_uboot_addr.ps1
```

This tests U-Boot at **0x01000000** (GXL TEXT_BASE) instead of 0x200c000.

## `update.exe` Command Reference

| Command | Description |
|---------|-------------|
| `identify` | Get device firmware version |
| `scan` | List USB devices |
| `write <file> <addr>` | Write file to RAM at address |
| `read <addr> <len> <file>` | Read from RAM |
| `run <addr>` | Execute code at address |
| `boot <file> <addr>` | Download + run in one step |
| `bulkcmd "<cmd>"` | Send U-Boot command via serial |
| `msdev` | Check for USB MSC device |
| `msget` / `msset` | Get/set MSC properties |
| `partition <cmd>` | Partition operations |
| `mwrite <file> <media> <part> <type>` | Write to media partition |
| `reset` | Reset device |
| `help` | Show help |

## Known Issues

- **USB selective suspend** must be disabled: `powercfg /setdcvalueindex SCHEME_CURRENT 238B25AD-6208-4E25-A941-F18BBA7AB1B0 4fc73751-79aa-4087-805d-7d1b4128be3f 0`
- **32 KB chunk limit** — larger transfers fail with `ret=-5` or `ret=-116`
- **Device hangs** after repeated operations — requires physical power cycle
- **PE export table corruption** in `UsbRomDrv.dll` — C# P/Invoke fails, use CLI instead
- **Encrypted U-Boot** — `CONFIG_AML_CRYPTO_UBOOT 1` means U-Boot binaries are encrypted; TPL may not decrypt when loaded via USB

## Excluded Files

The following large files are not included (use Git LFS if needed):

| File | Size | Location |
|------|------|----------|
| `part_system_big.bin` | 756 MB | `firmware/aml_upgrade_package/` |
| `part_system_big_raw.bin` | 1.4 GB | `firmware/aml_upgrade_package/` |
| `system.raw.img` | 1.8 GB | Pulpstone system partition (ext4) |

## License

Binary firmware files are proprietary (Amlogic, ZTE, PT Adi Reka Mandiri). Research files are from their respective open-source projects.
