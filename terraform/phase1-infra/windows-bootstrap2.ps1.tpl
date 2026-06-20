$ErrorActionPreference = "Stop"

# AD DS forest promotion: ports 53 (DNS), 88 (Kerberos), 135 (RPC), 389/636/3268/3269
# (LDAP/LDAPS/GC), 445 (SMB), 137-139 (NetBIOS). Windows enables the matching built-in
# firewall rule groups automatically as part of promotion.
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

$safeModePassword = ConvertTo-SecureString "${ad_safe_mode_password}" -AsPlainText -Force

Import-Module ADDSDeployment
Install-ADDSForest `
  -DomainName "${ad_domain_name}" `
  -SafeModeAdministratorPassword $safeModePassword `
  -InstallDns `
  -DomainMode "WinThreshold" `
  -ForestMode "WinThreshold" `
  -Force `
  -Confirm:$false `
  -NoRebootOnCompletion:$false
