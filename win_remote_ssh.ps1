# Configure and enable OpenSSH SSH Server on Windows 2019+

# Change this to a public SSH key to enable public key authentication
$publicKey = 'changeme'

# This should be commented out in case profiles have been already setup
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

$missing = Get-WindowsCapability -Name 'OpenSSH.Server*' -Online | ? State -ne 'Installed'
if ($missing) {
  Add-WindowsCapability -Name $missing.Name -Online
}

Start-Service -Name sshd
Set-Service -Name sshd -StartupType Automatic
Set-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -Value C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
if (!(Get-NetFirewallRule -Name OpenSSH-Server-In-TCP | Select-Object -Property Name, Enabled)) {
  New-NetFirewallRule `
    -Enabled True `
    -Name OpenSSH-Server-In-TCP `
    -DisplayName 'OpenSSH SSH Server (sshd)' `
    -Description 'Inbound rule for OpenSSH SSH Server (sshd)' `
    -Group 'OpenSSH Server' `
    -LocalPort 22 `
    -Action Allow `
    -Direction Inbound `
    -Protocol TCP `
    -Profile @('Domain', 'Private')
}

$keyFile = 'C:\ProgramData\ssh\administrators_authorized_keys'
if (!(Test-Path -Path $keyFile)) {
  New-Item -Path $keyFile
}
icacls.exe $keyFile /inheritance:r /grant ""Administrators:F"" /grant ""SYSTEM:F""
if ($publicKey.StartsWith('ssh')) {
  Add-Content -Path $keyFile -Value $publicKey
}
