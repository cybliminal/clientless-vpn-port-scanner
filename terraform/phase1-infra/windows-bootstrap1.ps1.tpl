$ErrorActionPreference = "Stop"

# IIS: ports 80/443
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# WinRM: ports 5985/5986 (enabled by default on the Azure image, but make sure)
Enable-PSRemoting -Force
winrm quickconfig -quiet

New-NetFirewallRule -DisplayName "Allow-IIS-HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "Allow-IIS-HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
New-NetFirewallRule -DisplayName "Allow-WinRM-HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
New-NetFirewallRule -DisplayName "Allow-WinRM-HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
