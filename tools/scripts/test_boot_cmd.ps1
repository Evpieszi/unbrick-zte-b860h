# Test the 'boot' command (download+run in one step)
# This might handle encryption differently than write+run

$updateExe = "E:\unbrick-workspace\tool\update.exe"

Write-Output "=== Step 1: Verify device ==="
$identify = & $updateExe identify 2>&1
Write-Output $identify
if ($identify -match "ret=-116") {
    Write-Output "Device not ready. Please power cycle and try again."
    exit 1
}

Write-Output ""
Write-Output "=== Step 2: Load DDR and run ==="
$ddrFile = "E:\unbrick-workspace\unpacked\Brick_thru\00_DDR_USB.bin"
$baseAddr = [Convert]::ToInt64("0xd9000000", 16)
$bytes = [System.IO.File]::ReadAllBytes($ddrFile)
$totalSize = $bytes.Length
$chunkSize = 32768
$numChunks = [Math]::Ceiling($totalSize / $chunkSize)
Write-Output "DDR: $totalSize bytes, $numChunks chunks"

$chunkDir = "E:\unbrick-workspace\tools\ddr_boot_chunks"
if (Test-Path $chunkDir) { Remove-Item $chunkDir -Recurse -Force }
New-Item -Path $chunkDir -ItemType Directory -Force | Out-Null

for ($i = 0; $i -lt $numChunks; $i++) {
    $offset = $i * $chunkSize
    $len = [Math]::Min($chunkSize, $totalSize - $offset)
    $chunkFile = Join-Path $chunkDir ("chunk_{0:D3}.bin" -f $i)
    $fs = [System.IO.File]::Create($chunkFile)
    $fs.Write($bytes, $offset, $len)
    $fs.Close()
}

$success = 0
for ($i = 0; $i -lt $numChunks; $i++) {
    $offset = $i * $chunkSize
    $targetAddr = "0x{0:X}" -f ($baseAddr + $offset)
    $chunkFile = Join-Path $chunkDir ("chunk_{0:D3}.bin" -f $i)
    $result = & $updateExe write $chunkFile $targetAddr 2>&1
    if ($LASTEXITCODE -eq 0) { $success++ }
    else {
        Write-Output "  Chunk $i FAILED, retrying..."
        Start-Sleep -Seconds 2
        & $updateExe write $chunkFile $targetAddr 2>&1
        if ($LASTEXITCODE -eq 0) { $success++ }
    }
}
Write-Output "DDR write: $success/$numChunks OK"

Write-Output ""
Write-Output "=== Step 3: Run DDR ==="
& $updateExe run "0xd9000000" 2>&1
Start-Sleep -Seconds 2

Write-Output ""
Write-Output "=== Step 4: Try 'boot' command with Pulpstone U-Boot at 0x01000000 ==="
$ubootFile = "E:\unbrick-workspace\tool\20191012\u-boot.bin"
Write-Output "Using: $ubootFile"
& $updateExe boot $ubootFile 0x01000000 2>&1
Write-Output "Waiting 10s..."
Start-Sleep -Seconds 10

Write-Output ""
Write-Output "=== Step 5: Check msdev ==="
& $updateExe msdev 2>&1

Write-Output ""
Write-Output "=== Step 6: Check bulkcmd printenv ==="
& $updateExe bulkcmd "printenv" 2>&1

Write-Output ""
Write-Output "=== Step 7: Try 'boot' command with Brick_thru U-Boot at 0x01000000 ==="
$ubootFile2 = "E:\unbrick-workspace\unpacked\Brick_thru\01_UBOOT_UBOOT.bin"
Write-Output "Using: $ubootFile2"
& $updateExe boot $ubootFile2 0x01000000 2>&1
Write-Output "Waiting 10s..."
Start-Sleep -Seconds 10

Write-Output ""
Write-Output "=== Step 8: Check msdev ==="
& $updateExe msdev 2>&1

Write-Output ""
Write-Output "=== Step 9: Check bulkcmd printenv ==="
& $updateExe bulkcmd "printenv" 2>&1

Write-Output ""
Write-Output "=== Done ==="
