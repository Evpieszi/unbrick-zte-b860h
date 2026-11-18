# Troubleshooting

## Device Not Detected

### Symptom
```
update.exe identify
# ret=-116
# or: "can not find device"
```

### Solution
1. **Power cycle the STB**:
   - Unplug USB cable
   - Unplug power adapter
   - Wait 10 seconds
   - Plug in power adapter
   - Plug in USB cable
   - Wait 10-15 seconds

2. **Verify in Windows**:
   ```powershell
   Get-WmiObject Win32_PnPEntity -Filter "Name LIKE '%WorldCup%'"
   ```
   Should show: `WorldCup Device` with status `OK`

3. **Check USB controller**:
   ```powershell
   Get-WmiObject Win32_PnPEntity -Filter "Name LIKE '%eXtensible Host%'"
   ```
   Should show: `AMD USB 3.10 eXtensible Host Controller` with status `OK`

## USB Write Failures

### Symptom
```
update.exe write <file> <addr>
# ret=-5
# or: "A device attached to the system is not functioning"
```

### Solution
- **Use 32 KB chunks** (see `tools/scripts/unbrick.ps1`)
- **Disable USB selective suspend**:
  ```powershell
  powercfg /setdcvalueindex SCHEME_CURRENT 238B25AD-6208-4E25-A941-F18BBA7AB1B0 4fc73751-79aa-4087-805d-7d1b4128be3f 0
  powercfg /setactiveplan SCHEME_CURRENT
  ```
- **Use USB 2.0 port** (rear, motherboard) — USB 3.0 is worse
- **Use 12V 2A power adapter** — USB-only power is unreliable
- **Use a short USB cable**

## C# P/Invoke Failures

### Symptom
```
DllNotFoundException: Unable to load DLL 'UsbRomDrv.dll'
# or:
EntryPointNotFoundException: The specified entry point could not be located
```

### Cause
The PE export table in `UsbRomDrv.dll` is corrupted:
- NumNames = 0
- AddressOfFunctions = 0
- Ordinal-only exports (no names)

### Solution
- **Use the CLI** (`update.exe`) instead of C# P/Invoke
- The CLI works because it uses the DLL internally, not through P/Invoke

## U-Boot Runs But No eMMC/Serial

### Symptom
```
update.exe run 0x200c000
# [update]:Run at Addr 200c000
# AmlUsbRunBinCode:ram_addr=200c000

update.exe msdev
# can not find device

update.exe bulkcmd "printenv"
# (timeout)
# or: ret=-5
```

### Possible Causes
1. **Wrong U-Boot load address** — Try 0x01000000 (GXL TEXT_BASE)
2. **Encrypted U-Boot** — TPL may not decrypt when loaded via USB
3. **Secure boot key mismatch** — U-Boot rejected by security check
4. **Missing DTB** — U-Boot can't initialize peripherals without DTB
5. **Dead eMMC** — Hardware failure

### Diagnostic Steps
```powershell
# 1. Verify device
update.exe identify

# 2. Load and run DDR
update.exe write ddr.bin 0xd9000000
update.exe run 0xd9000000

# 3. Check if eMMC is detected
update.exe msdev

# 4. Load U-Boot at TEXT_BASE
update.exe write u-boot.bin 0x01000000
update.exe run 0x01000000

# 5. Check again
update.exe msdev
update.exe bulkcmd "printenv"
update.exe bulkcmd "mmc dev"
```

## Driver Issues

### Symptom
```
# WorldCup Device not appearing in Device Manager
# or: "Unknown device" with warning icon
```

### Solution
1. Run `tools/WorldCup_Device/InstallDriver.exe`
2. Restart the computer
3. Verify in Device Manager:
   - Should show: `WorldCup Device` under `Universal Serial Bus controllers`
