# Configure WinRM/PSRP encrypted connection
# Allow access for a non-Administrator user

# This should be commented out in case profiles have been already setup
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

Start-Service -Name WinRM
Set-Service -Name WinRM -StartupType Automatic
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned

# Allow NTLM also for a non-Administrator in Administrators
$user = 'winrm'
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name LocalAccountTokenFilterPolicy -Value 1
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

$rule = Get-NetFirewallRule -Name WINRM-HTTP-In-TCP -ErrorAction SilentlyContinue
if (-not $rule) {
  New-NetFirewallRule `
    -Enabled True `
    -Name WINRM-HTTP-In-TCP `
    -DisplayName 'Windows Remote Management (HTTP-In)' `
    -Description 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5985]' `
    -DisplayGroup 'Windows Remote Management'
    -Group '@FirewallAPI.dll,-30267' `
    -LocalPort 5985 `
    -Action Allow `
    -Direction Inbound `
    -Protocol TCP `
    -Profile @('Domain', 'Private')
}
if ($rule -and ($rule.Enabled -ne $true -or $rule.Action -ne 'Allow')) {
  Set-NetFirewallRule -Name WINRM-HTTP-In-TCP -Enabled True -Profile @('Domain', 'Private') -Action Allow
}

# WinRM/HTTPS
#$friendlyName = 'WinRM over HTTPS'
#$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My `
#          -DnsName $env:COMPUTERNAME -NotAfter (get-date).AddYears(10) `
#          -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' `
#          -KeyLength 4096
#$cert.FriendlyName = $friendlyName
#Set-WSManInstance -ResourceURI winrm/config/Listener `
#  -SelectorSet @{Address='*';Transport='HTTPS'} `
#  -ValueSet @{CertificateThumbprint=$cert.Thumbprint;Enabled=$true}
#$rule = Get-NetFirewallRule -Name WINRM-HTTPS-In-TCP -ErrorAction SilentlyContinue
#if (-not $rule) {
#  New-NetFirewallRule `
#    -Enabled True `
#    -Name WINRM-HTTPS-In-TCP `
#    -DisplayName 'Windows Remote Management (HTTPS-In)' `
#    -Description 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]' `
#    -DisplayGroup 'Windows Remote Management'
#    -Group '@FirewallAPI.dll,-30267' `
#    -LocalPort 5986 `
#    -Action Allow `
#    -Direction Inbound `
#    -Protocol TCP `
#    -Profile @('Domain', 'Private')
#}
#if ($rule -and ($rule.Enabled -ne $true -or $rule.Action -ne 'Allow')) {
#  Set-NetFirewallRule -Name WINRM-HTTPS-In-TCP -Enabled True -Profile @('Domain', 'Private') -Action Allow
#}
