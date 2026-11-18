# Technical Findings

## 1. USB Write Chunk Size Limit

| Chunk Size | Success Rate | Notes |
|------------|--------------|-------|
| 32 KB | 100% | Reliable |
| 64 KB | ~50% | Intermittent failures |
| 68 KB+ | <10% | Almost always fails |

**Conclusion**: Use 32 KB chunks for all USB writes.

## 2. `update.exe` Command Set (v0.8.1)

Full command set discovered:
- `partition` — Partition operations
- `mwrite` — Write to media partition
- `mread` — Read from media partition
- `write` — Write file to RAM
- `read` — Read from RAM
- `bulkcmd` — Send U-Boot command via serial
- `identify` — Get device info
- `reset` — Reset device
- `scan` — List USB devices
- `boot` — Download + run in one step
- `msdev` — Check for USB MSC device
- `msget` / `msset` — Get/set MSC properties
- `help` — Show help

### Command Behavior

| Command | Result | Notes |
|---------|--------|-------|
| `identify` | Returns firmware version | Works in WorldCup mode |
| `scan` | Lists USB host controller | Does NOT list WorldCup device |
| `write <file> <addr>` | Writes to RAM | 32 KB chunks reliable |
| `run <addr>` | Executes code | TPL jumps to address |
| `msdev` | "can not find device" | Fails after U-Boot run |
| `msget` | "can not find device" | Fails after U-Boot run |
| `bulkcmd "<cmd>"` | Timeout or ret=-5 | U-Boot serial never comes up |
| `partition boot <file>` | "Usb status not success" | TPL protocol needs U-Boot alive |
| `mwrite <file> store boot normal` | "Usb status not success" | Same as above |

## 3. PE Export Table Corruption

Both `update.exe` and `UsbRomDrv.dll` have corrupted PE export tables:

- **NumNames** = 0
- **DllName** = "KERNEL32.dll"
- **AddressOfFunctions** = 0
- **Export type**: Ordinal-only (no names)
- **GetProcAddress** returns 0 for all names/ordinals

**Impact**: C# P/Invoke fails. **Workaround**: Use the CLI (`update.exe`) directly.

### Import Table of `update.exe`

Imports from `UsbRomDrv.dll`:
- `AmlUsbBulkCmd@4`
- `AmlUsbReadStatus@4`
- `AmlUsbTplCmd@4`
- `AmlUsbburn@32`
- `AmlResetDev@4`
- `AmlUsbIdentifyHost@4`
- `AmlSetFileCopyCompleteEx@12`
- `AmlGetUpdateComplete@12`
- `AmlUsbCtrlWr@4`
- `AmlUsbWriteLargeMem@4`
- `AmlUsbReadLargeMem@4`
- `AmlUsbRunBinCode@4`
- `AmlWriteMedia@4`
- `AmlReadMedia@4`

## 4. Firmware Binary Headers

| Binary | Size | First 16 bytes (hex) | Type |
|--------|------|----------------------|------|
| Brick_thru DDR | 1,179,744 B | `01 00 64 AA 78 56 34 12 ...` | TPL (structured header) |
| AML DDR | 884,736 B | `00 00 00 02 01 00 01 00 ... 41 4D 4C 43` | TPL (structured header, "AMLC") |
| Pulpstone U-Boot | 1,229,408 B | `84 1B 16 0D 48 85 4C 37 ...` | Encrypted (random header) |
| Pulpstone USB SPL | 49,664 B | `A5 79 CE 2B E8 7C 47 6C ...` | Encrypted (random header) |
| Brick_thru U-Boot | 934,400 B | `81 42 0C F9 2E 7B 58 32 ...` | Encrypted (random header) |

**Conclusion**: All U-Boot binaries are **encrypted** (consistent with `CONFIG_AML_CRYPTO_UBOOT 1`). The TPL may not decrypt them when loaded via USB.

## 5. Board Configuration Analysis

From `board_amlogic_configs_gxl_p212_v1.h`:

### Critical Flags

| Flag | Value | Impact |
|------|-------|--------|
| `CONFIG_AML_SD_EMMC` | 1 | eMMC enabled |
| `CONFIG_USB_GADGET` | 1 | USB gadget enabled |
| `CONFIG_USBDOWNLOAD_GADGET` | 1 | USB download mode |
| `CONFIG_AML_SECURE_UBOOT` | 1 | **Secure boot enabled** |
| `CONFIG_AML_CRYPTO_UBOOT` | 1 | **U-Boot is encrypted** |
| `CONFIG_SECURE_STORAGE` | 1 | Secure storage |
| `CONFIG_NEED_BL301` | 1 | Needs ARM Trusted Firmware BL301 |
| `CONFIG_NEED_BL32` | 1 | Needs ARM Trusted Firmware BL32 |
| `CONFIG_MULTI_DTB` | 1 | Multiple DTB support |
| `CONFIG_FIP_IMG_SUPPORT` | 1 | FIP image format |
| `CONFIG_EFUSE` | 1 | eFuse support |
| `CONFIG_DEVICE_PRODUCT` | "ampere" | Product name |

### Addresses

| Name | Address | Notes |
|------|---------|-------|
| ISABASE (TEXT_BASE) | `0x01000000` | GXL U-Boot entry point |
| DWC_REG_BASE | `0xC9000000` | USB DWC register base |
| PREI_USB_PHY_A | `0xC0000000` | USB PHY A |
| PREI_USB_PHY_B | `0xC0000020` | USB PHY B |
| GXL_XHCI_BASE | `0xC9000000` | XHCI base |
| GXL_USB_PHY2 | `0xD0078000` | USB PHY2 |
| GXL_USB_PHY3 | `0xD0078080` | USB PHY3 |
| DDR load/run | `0xd9000000` | TPL DDR address |
| U-Boot load (current) | `0x200c000` | Possibly wrong |
| bl2ParaAddr | `0xd900c000` | BL2 parameters |
| Encrypt register | `0xc8100228` | Encryption control |

## 6. Unresolved Questions

1. **Why does U-Boot run but never initialize eMMC/serial?**
   - Hypothesis 1: Wrong load address (0x200c000 vs 0x01000000)
   - Hypothesis 2: Encrypted U-Boot not decrypted by TPL
   - Hypothesis 3: Secure boot key mismatch
   - Hypothesis 4: Missing DTB
   - Hypothesis 5: Dead eMMC hardware

2. **Does the TPL decrypt U-Boot when loaded via USB?**
   - The TPL's USB download mode may not go through the normal decryption path
   - Need to find a non-encrypted U-Boot or the encryption key

3. **Is the eMMC hardware functional?**
   - If no U-Boot variant can initialize it, the eMMC may be dead
   - Would require JTAG recovery or spare eMMC

## 7. Next Steps

1. **Power cycle STB** (device currently in `ret=-116` state)
2. **Test U-Boot at 0x01000000** (TEXT_BASE) — see `tools/scripts/test_uboot_addr.ps1`
3. **Test `boot` command** (download+run in one step) — see `tools/scripts/test_boot_cmd.ps1`
4. **Find non-encrypted U-Boot** for GXL P212
5. **Check eMMC hardware** (if all software approaches fail)
