#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$ShareName = 'VM-Share',
    [string]$SharePath = 'C:\VM-Share',
    [string]$AllowedUser = $env:USERNAME,
    [string]$AllowedSubnet = '192.168.50.0/24'
)

$ErrorActionPreference = 'Stop'
$FirewallRuleName = 'FEDORA_GNOME_CUSTOM SMB from devops-nat'

if ([string]::IsNullOrWhiteSpace($AllowedUser)) {
    throw 'AllowedUser cannot be empty.'
}

Write-Host "Configuring authenticated SMB share $ShareName at $SharePath for $AllowedUser"

Set-Service -Name LanmanServer -StartupType Automatic
Start-Service -Name LanmanServer
New-Item -ItemType Directory -Path $SharePath -Force | Out-Null

$acl = Get-Acl -Path $SharePath
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $AllowedUser,
    'Modify',
    'ContainerInherit,ObjectInherit',
    'None',
    'Allow'
)
$acl.SetAccessRule($accessRule)
Set-Acl -Path $SharePath -AclObject $acl

$existing = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    New-SmbShare -Name $ShareName -Path $SharePath -FullAccess $AllowedUser -CachingMode None | Out-Null
} elseif ($existing.Path -ne $SharePath) {
    throw "SMB share $ShareName already exists with a different path: $($existing.Path)"
} else {
    Grant-SmbShareAccess -Name $ShareName -AccountName $AllowedUser -AccessRight Full -Force | Out-Null
    Set-SmbShare -Name $ShareName -CachingMode None -Force
}

Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule `
    -DisplayName $FirewallRuleName `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 445 `
    -RemoteAddress $AllowedSubnet `
    -Profile Any | Out-Null

Write-Host 'SMB configuration complete.'
Write-Host "Share: \\$env:COMPUTERNAME\$ShareName"
Write-Host "Allowed source network: $AllowedSubnet"
Write-Host 'Use the Windows account credentials when Nautilus asks for authentication.'
