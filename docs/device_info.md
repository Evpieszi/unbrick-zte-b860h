# Device Information

## Identity

| Property | Value |
|----------|-------|
| Model | ZTE B860H v1 |
| Manufacturer | PT Adi Reka Mandiri |
| SoC | Amlogic S905X / GXL P212 |
| CPU | Cortex-A53 (quad-core) |
| RAM | 1 GB DDR (auto-detect type) |
| Storage | 8 GB eMMC |
| USB | USB 2.0 (rear, motherboard) |
| Power | 12V 2A adapter |
| USB Device ID | VID_1B8E & PID_C003 |
| Recovery mode | WorldCup (auto-enters on power) |

## USB Configuration

- **Port**: USB 2.0 rear (motherboard)
- **Cable**: Short cable recommended
- **Power**: 12V 2A adapter (USB-only power is unreliable)
- **USB selective suspend**: Must be **disabled** (index 0x00000000)

### Disabling USB selective suspend

```powershell
powercfg /setdcvalueindex SCHEME_CURRENT 238B25AD-6208-4E25-A941-F18BBA7AB1B0 4fc73751-79aa-4087-805d-7d1b4128be3f 0
powercfg /setactiveplan SCHEME_CURRENT
```

Verify:
```powershell
powercfg /query SCHEME_CURRENT 238B25AD-6208-4E25-A941-F18BBA7AB1B0 4fc73751-79aa-4087-805d-7d1b4128be3f
# Should show: Index 0x00000000
```

## WorldCup Mode

The device auto-enters WorldCup USB-ROM mode on power. No reset button or pin press needed.

When in WorldCup mode:
- Device appears as `WorldCup Device` in Windows Device Manager
- `update.exe identify` returns firmware version
- `update.exe write` can write to RAM
- `update.exe run` can execute code

## Driver Installation

The WorldCup device requires a specific USB driver:

```
tools/WorldCup_Device/InstallDriver.exe
```

This installs the `libusb0.sys` driver for both x86 and amd64.

## Power Cycle Procedure

When the device enters a bad state (`ret=-116`):

1. Unplug USB cable
2. Unplug power adapter
3. Wait 10 seconds
4. Plug in power adapter
5. Plug in USB cable
6. Wait 10-15 seconds for Windows to detect
