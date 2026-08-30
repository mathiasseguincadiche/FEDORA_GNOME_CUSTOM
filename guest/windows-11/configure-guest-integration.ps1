#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

Write-Host "[FGC] Detecting VirtIO media..."
$cdroms = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=5"
$virtio = $null
foreach ($disk in $cdroms) {
    if (Test-Path (Join-Path $disk.DeviceID "guest-agent")) {
        $virtio = $disk.DeviceID
        break
    }
}
if (-not $virtio) { throw "virtio-win media not found. Attach the operator-supplied virtio-win ISO." }

Write-Host "[FGC] Installing/updating signed VirtIO drivers..."
pnputil.exe /add-driver "$virtio\*.inf" /subdirs /install | Out-Host

$qga = Get-ChildItem -Path "$virtio\guest-agent" -Filter "qemu-ga-x86_64.msi" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $qga) { throw "QEMU Guest Agent MSI not found on VirtIO media." }
Write-Host "[FGC] Installing QEMU Guest Agent..."
Start-Process msiexec.exe -ArgumentList "/i `"$($qga.FullName)`" /qn /norestart" -Wait
Set-Service -Name QEMU-GA -StartupType Automatic
Start-Service -Name QEMU-GA

$badVirtio = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^PCI\\VEN_1AF4' -and $_.Status -ne 'OK' }
if ($badVirtio) { $badVirtio | Format-Table -AutoSize | Out-Host; throw "One or more VirtIO devices are not healthy." }
$qgaService = Get-Service -Name QEMU-GA -ErrorAction Stop
if ($qgaService.Status -ne 'Running') { throw "QEMU Guest Agent service is not running." }

Write-Host "[FGC] VirtIO devices and QEMU Guest Agent are healthy."
Write-Host "[FGC] SPICE channel is exposed by libvirt; install a Windows SPICE agent only if clipboard/dynamic-resize integration is desired."
