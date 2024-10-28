# Configure and enable Basic-over-HTTPS WinRM on Windows 2016+
# Configure and enable NTLM-over-HTTP/S WinRM for non-Administrator

# This should be commented out in case profiles have been already setup
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

Start-Service -Name WinRM
Set-Service -Name WinRM -StartupType Automatic

# Allow NTLM for non-Administrator
$user = 'winrm'
$sid = (New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $user).Translate([System.Security.Principal.SecurityIdentifier])
$sddl = (Get-Item -Path WSMan:\localhost\Service\RootSDDL).Value
$sd = New-Object -TypeName System.Security.AccessControl.CommonSecurityDescriptor -ArgumentList $false, $false, $sddl
$sd.DiscretionaryAcl.AddAccess(
  [System.Security.AccessControl.AccessControlType]::Allow,
  $sid,
  [int]0x10000000,
  [System.Security.AccessControl.InheritanceFlags]::None,
  [System.Security.AccessControl.PropagationFlags]::None
  )
$sddl = $sd.GetSddlForm([System.Security.AccessControl.AccessControlSections]::All)
Set-Item -Path WSMan:\localhost\Service\RootSDDL -Value $sddl -Force

# Basic-over-HTTPS
if (!(Get-NetFirewallRule -Name WINRM-HTTPS-In-TCP -ErrorAction SilentlyContinue | Select-Object -Property Name, Enabled)) {
  New-NetFirewallRule `
    -Enabled True `
    -Name WINRM-HTTPS-In-TCP `
    -DisplayName 'Windows Remote Management (HTTPS-In)' `
    -Description 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]' `
    -Group '@FirewallAPI.dll,-30267' `
    -LocalPort 5986 `
    -Action Allow `
    -Direction Inbound `
    -Protocol TCP `
    -Profile @('Domain', 'Private')
}

$friendlyName = 'WinRM over HTTPS'
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My `
          -DnsName $env:COMPUTERNAME -NotAfter (get-date).AddYears(10) `
          -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' `
          -KeyLength 4096
$cert.FriendlyName = $friendlyName
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS `
  -Address * -CertificateThumbPrint $cert.Thumbprint -Force

Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
