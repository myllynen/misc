# Configure and enable OpenSSH SSH Server on Windows Server 2019+

# Change this to a public SSH key to enable public key authentication
$publicKey = 'changeme'

# This should be commented out in case profiles have been already setup
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

$missing = Get-WindowsCapability -Name 'OpenSSH.Server*' -Online | ? State -ne 'Installed'
if ($missing) {
  Add-WindowsCapability -Name $missing.Name -Online
  if ((Get-WindowsCapability -Name $missing.Name -Online | ? State -ne 'Installed')) {
    Write-Host 'Failed to install OpenSSH.Server capability.'
    Exit 1
  }
}

Start-Service -Name sshd
Set-Service -Name sshd -StartupType Automatic
Set-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -Value C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe

$rule = Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue
if (-not $rule) {
  New-NetFirewallRule `
    -Enabled True `
    -Name OpenSSH-Server-In-TCP `
    -DisplayName 'OpenSSH SSH Server (sshd)' `
    -Description 'Inbound rule for OpenSSH SSH Server (sshd)' `
    -DisplayGroup 'OpenSSH Server' `
    -Group 'OpenSSH Server' `
    -LocalPort 22 `
    -Action Allow `
    -Direction Inbound `
    -Protocol TCP `
    -Profile @('Domain', 'Private')
}
if ($rule -and ($rule.Enabled -ne $true -or $rule.Action -ne 'Allow')) {
  Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Enabled True -Profile @('Domain', 'Private') -Action Allow
}

$keyFile = 'C:\ProgramData\ssh\administrators_authorized_keys'
if (-not (Test-Path -Path $keyFile)) {
  New-Item -Path $keyFile -ItemType File
}
icacls.exe $keyFile /inheritance:r /grant ""Administrators:F"" /grant ""SYSTEM:F""
if ($publicKey.StartsWith('ssh')) {
  Add-Content -Path $keyFile -Value $publicKey
}
