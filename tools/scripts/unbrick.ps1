# unbrick.ps1 - Unbrick ZTE B860H v1 STB via USB-ROM mode
# Uses update.exe CLI with 64K chunked writes and retry logic.
#
# Prerequisites:
#   - Device in WorldCup (USB-ROM) mode
#   - 12V 2A power adapter connected
#   - USB 2.0 port on motherboard (rear)
#   - Short USB cable (<30cm)
#   - USB selective suspend disabled
#
# Usage: powershell -ExecutionPolicy Bypass -File unbrick.ps1

$ErrorActionPreference = "Continue"
$toolDir = "E:\unbrick-workspace\tool"
$unpackedDir = "E:\unbrick-workspace\unpacked\Brick_thru"
$workDir = "E:\unbrick-workspace\tools\chunks"
$chunkSize = 32768  # 32K - reliable (64K is ~50% success rate)
$maxRetries = 3

# Addresses (from platform.conf + burn_config.xml)
$ddrAddr = "0xd9000000"
$ubootAddr = "0x200c000"

$ddrFile = Join-Path $unpackedDir "00_DDR_USB.bin"
$ubootFile = Join-Path $unpackedDir "01_UBOOT_UBOOT.bin"
$updateExe = Join-Path $toolDir "update.exe"

function Write-Log($msg) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg)
}

function Invoke-Update($params) {
    $exe = $updateExe
    $fullParams = $params -join " "
    Write-Verbose "  Exec: update.exe $fullParams"
    try {
        $output = & $exe $params 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $output = $_.Exception.Message
        $exitCode = -1
    }
    $outStr = $output -join " "
    Write-Verbose "  Out: $outStr"
    return @{ ExitCode = $exitCode; StdOut = $outStr }
}

function Test-Device {
    Write-Log "Checking device connection..."
    $result = Invoke-Update @("identify")
    if ($result.ExitCode -ne 0) {
        Write-Log "  Device not found (exit=$($result.ExitCode))"
        return $false
    }
    Write-Log "  Device OK: $($result.StdOut.Trim())"
    return $true
}

function Write-Chunks($sourceFile, $baseAddr, $label) {
    $bytes = [System.IO.File]::ReadAllBytes($sourceFile)
    $totalSize = $bytes.Length
    $numChunks = [Math]::Ceiling($totalSize / $chunkSize)
    
    Write-Log "Writing ${label}: $totalSize bytes in $numChunks chunks of ${chunkSize}B"
    
    # Create chunk directory
    $chunkDir = Join-Path $workDir $label
    if (Test-Path $chunkDir) { Remove-Item $chunkDir -Recurse -Force }
    New-Item -Path $chunkDir -ItemType Directory -Force | Out-Null
    
    # Create chunk files
    for ($i = 0; $i -lt $numChunks; $i++) {
        $offset = $i * $chunkSize
        $len = [Math]::Min($chunkSize, $totalSize - $offset)
        $chunkFile = Join-Path $chunkDir ("chunk_{0:D3}.bin" -f $i)
        $fs = [System.IO.File]::Create($chunkFile)
        $fs.Write($bytes, $offset, $len)
        $fs.Close()
    }
    
    # Write each chunk with retry
    $success = 0
    for ($i = 0; $i -lt $numChunks; $i++) {
        $offset = $i * $chunkSize
        $targetAddr = ("0x{0:X}" -f ([Convert]::ToInt64($baseAddr, 16) + $offset))
        $chunkFile = Join-Path $chunkDir ("chunk_{0:D3}.bin" -f $i)
        $chunkLen = [Math]::Min($chunkSize, $totalSize - $offset)
        
        $retry = 0
        $ok = $false
        while ($retry -lt $maxRetries -and -not $ok) {
            $retry++
            Write-Log "  Chunk $i/$numChunks ($chunkLen B) -> $targetAddr (attempt $retry)"
            $result = Invoke-Update @("write", $chunkFile, $targetAddr)
            if ($result.ExitCode -eq 0) {
                $ok = $true
            } else {
                Write-Log "    FAILED (exit=$($result.ExitCode)), waiting 2s..."
                Start-Sleep -Seconds 2
                # Check if device is still alive
                if (-not (Test-Device)) {
                    Write-Log "    Device lost! Waiting 5s for recovery..."
                    Start-Sleep -Seconds 5
                }
            }
        }
        
        if ($ok) {
            $success++
        } else {
            Write-Log "  Chunk $i FAILED after $maxRetries retries"
            return $false
        }
    }
    
    Write-Log "  ${label}: $success/$numChunks chunks written OK"
    return $success -eq $numChunks
}

function Run-Code($addr, $label) {
    Write-Log "Running $label at $addr..."
    $result = Invoke-Update @("run", $addr)
    if ($result.ExitCode -ne 0) {
        Write-Log "  Run FAILED (exit=$($result.ExitCode))"
        return $false
    }
    Write-Log "  $label run OK"
    return $true
}

# === Main ===
Write-Log "=== ZTE B860H v1 Unbrick Script ==="
Write-Log "DDR file: $ddrFile ($([System.IO.File]::ReadAllBytes($ddrFile).Length) bytes)"
Write-Log "UBOOT file: $ubootFile ($([System.IO.File]::ReadAllBytes($ubootFile).Length) bytes)"
Write-Log ""

# Step 1: Check device
if (-not (Test-Device)) {
    Write-Log "ERROR: Device not found. Make sure it's in WorldCup mode."
    Write-Log "  - 12V power adapter connected"
    Write-Log "  - USB 2.0 port (rear, motherboard)"
    Write-Log "  - Short cable, no hub"
    exit 1
}

# Step 2: Write DDR blob
Write-Log ""
Write-Log "=== Step 2: Writing DDR blob ==="
if (-not (Write-Chunks $ddrFile $ddrAddr "DDR")) {
    Write-Log "ERROR: DDR write failed"
    exit 2
}

# Step 3: Run DDR blob
Write-Log ""
Write-Log "=== Step 3: Running DDR blob ==="
if (-not (Run-Code $ddrAddr "DDR")) {
    Write-Log "ERROR: DDR run failed"
    exit 3
}
Start-Sleep -Seconds 3

# Step 4: Write UBOOT blob
Write-Log ""
Write-Log "=== Step 4: Writing UBOOT blob ==="
if (-not (Write-Chunks $ubootFile $ubootAddr "UBOOT")) {
    Write-Log "ERROR: UBOOT write failed"
    exit 4
}

# Step 5: Run UBOOT blob
Write-Log ""
Write-Log "=== Step 5: Running UBOOT blob ==="
if (-not (Run-Code $ubootAddr "UBOOT")) {
    Write-Log "ERROR: UBOOT run failed"
    exit 5
}
Start-Sleep -Seconds 5

# Step 6: Verify
Write-Log ""
Write-Log "=== Step 6: Verifying ==="
$deviceAlive = Test-Device
if ($deviceAlive) {
    Write-Log "  Device still alive after UBOOT run"
    $result = Invoke-Update @("bulkcmd", "printenv")
    Write-Log "  printenv output:"
    Write-Log "  $($result.StdOut.Trim())"
} else {
    Write-Log "  Device no longer responds (expected if UBOOT took over)"
    Write-Log "  Check if STB boots to normal firmware."
}

Write-Log ""
Write-Log "=== Done ==="
Write-Log "If the STB boots normally, the unbrick was successful."
Write-Log "If not, try re-entering WorldCup mode and running again."
