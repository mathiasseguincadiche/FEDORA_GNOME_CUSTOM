#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

Write-Host "[FGC] Detecting VirtIO media..."
$cdroms = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=5"
$virtio = $null
foreach ($disk in $cdroms) {
    if (Test-Path (Join-Path $disk.DeviceID "guest-agent")) { $virtio = $disk.DeviceID; break }
}
if (-not $virtio) { throw "virtio-win media not found. Attach the operator-supplied virtio-win ISO." }

Write-Host "[FGC] Installing/updating signed VirtIO drivers..."
pnputil.exe /add-driver "$virtio\*.inf" /subdirs /install | Out-Host
$qga = Get-ChildItem -Path "$virtio\guest-agent" -Filter "qemu-ga-x86_64.msi" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $qga) { throw "QEMU Guest Agent MSI not found on VirtIO media." }
Start-Process msiexec.exe -ArgumentList "/i `"$($qga.FullName)`" /qn /norestart" -Wait
Set-Service -Name QEMU-GA -StartupType Automatic
Start-Service -Name QEMU-GA

$virtioDevices = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^PCI\\VEN_1AF4' }
$badVirtio = $virtioDevices | Where-Object { $_.Status -ne 'OK' }
if ($badVirtio) { $badVirtio | Format-Table -AutoSize | Out-Host; throw "One or more VirtIO devices are not healthy." }
$network = $virtioDevices | Where-Object { $_.InstanceId -match '&DEV_(1000|1041)(&|\\)' -and $_.Status -eq 'OK' }
$storage = $virtioDevices | Where-Object { $_.InstanceId -match '&DEV_(1001|1004|1042|1048)(&|\\)' -and $_.Status -eq 'OK' }
$balloon = $virtioDevices | Where-Object { $_.InstanceId -match '&DEV_(1002|1045)(&|\\)' -and $_.Status -eq 'OK' }
if (-not $network) { throw "Healthy VirtIO network device not found." }
if (-not $storage) { throw "Healthy VirtIO storage device not found." }
if (-not $balloon) { throw "Healthy VirtIO balloon device not found." }
$qgaService = Get-Service -Name QEMU-GA -ErrorAction Stop
if ($qgaService.Status -ne 'Running') { throw "QEMU Guest Agent service is not running." }

$markerDir = 'C:\ProgramData\FedoraGnomeCustom'
$markerPath = Join-Path $markerDir 'guest-integration.json'
New-Item -ItemType Directory -Force -Path $markerDir | Out-Null
$marker = [ordered]@{
    schema = 2
    verdict = 'PASS'
    generated_utc = [DateTime]::UtcNow.ToString('o')
    virtio_bad_count = 0
    virtio_storage = 'PASS'
    virtio_network = 'PASS'
    virtio_balloon = 'PASS'
    qemu_ga = 'PASS'
}
$json = $marker | ConvertTo-Json -Depth 3
[IO.File]::WriteAllText($markerPath, $json, (New-Object Text.UTF8Encoding($false)))
Write-Host "[FGC] VirtIO/QEMU-GA certification marker: $markerPath"
Write-Host "[FGC] VirtIO storage, network, balloon and QEMU Guest Agent are healthy."
