param(
    [Parameter(Mandatory=$true)]
    [string]$SqlSaPassword
)

$ErrorActionPreference = "Stop"
$logFile = "C:\setup-log.txt"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $logFile
    Write-Host $Message
}

Write-Log "=== Starting IIS and SQL Server Setup ==="

# --- Install IIS and Required Features ---
Write-Log "Installing IIS and ASP.NET 4.5 features..."
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-Asp-Net45
Install-WindowsFeature -Name Web-Net-Ext45
Install-WindowsFeature -Name Web-ISAPI-Ext
Install-WindowsFeature -Name Web-ISAPI-Filter
Install-WindowsFeature -Name Web-Mgmt-Console
Install-WindowsFeature -Name Web-Scripting-Tools
Install-WindowsFeature -Name NET-Framework-45-ASPNET
Install-WindowsFeature -Name NET-WCF-HTTP-Activation45

Write-Log "IIS installation complete."

# --- Install Web Deploy 3.6 ---
Write-Log "Downloading Web Deploy..."
$webDeployUrl = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
$webDeployInstaller = "C:\temp\WebDeploy.msi"

New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
Invoke-WebRequest -Uri $webDeployUrl -OutFile $webDeployInstaller -UseBasicParsing

Write-Log "Installing Web Deploy..."
Start-Process msiexec.exe -ArgumentList "/i `"$webDeployInstaller`" /quiet /norestart ADDLOCAL=ALL" -Wait -NoNewWindow
Write-Log "Web Deploy installation complete."

# --- Install SQL Server Express 2016 ---
Write-Log "Downloading SQL Server 2016 Express..."
$sqlUrl = "https://download.microsoft.com/download/9/0/7/907AD35F-9F9C-43A5-9789-52470555DB90/ENU/SQLEXPR_x64_ENU.exe"
$sqlInstaller = "C:\temp\SQLEXPR_x64_ENU.exe"

Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller -UseBasicParsing

Write-Log "Extracting SQL Server installer..."
Start-Process $sqlInstaller -ArgumentList "/qs /x:C:\temp\sqlsetup" -Wait -NoNewWindow

Write-Log "Installing SQL Server Express..."
$sqlArgs = @(
    "/Q",
    "/ACTION=Install",
    "/FEATURES=SQLEngine",
    "/INSTANCENAME=MSSQLSERVER",
    "/SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`"",
    "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`"",
    "/SECURITYMODE=SQL",
    "/SAPWD=`"$SqlSaPassword`"",
    "/TCPENABLED=1",
    "/NPENABLED=1",
    "/IACCEPTSQLSERVERLICENSETERMS"
)

Start-Process "C:\temp\sqlsetup\setup.exe" -ArgumentList ($sqlArgs -join " ") -Wait -NoNewWindow
Write-Log "SQL Server Express installation complete."

# --- Configure SQL Server for TCP/IP ---
Write-Log "Configuring SQL Server networking..."
Import-Module SqlPs -DisableNameChecking -ErrorAction SilentlyContinue

# Enable TCP/IP protocol
$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
$tcp = $wmi.ServerInstances['MSSQLSERVER'].ServerProtocols['Tcp']
$tcp.IsEnabled = $true
$tcp.Alter()

# Restart SQL Server to apply network changes
Restart-Service -Name MSSQLSERVER -Force
Write-Log "SQL Server networking configured."

# --- Create PropertyManagement Database ---
Write-Log "Creating PropertyManagement database..."
$query = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'PropertyManagement')
BEGIN
    CREATE DATABASE PropertyManagement;
END
"@

Invoke-Sqlcmd -Query $query -ServerInstance "localhost" -ErrorAction SilentlyContinue
Write-Log "PropertyManagement database created."

# --- Configure Windows Firewall ---
Write-Log "Configuring firewall rules..."
New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
New-NetFirewallRule -DisplayName "HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
New-NetFirewallRule -DisplayName "Web Deploy" -Direction Inbound -Protocol TCP -LocalPort 8172 -Action Allow
Write-Log "Firewall rules configured."

# --- Configure IIS Default Site ---
Write-Log "Configuring IIS default website..."
Import-Module WebAdministration

# Set default app pool to .NET 4.0 (which includes 4.6.2 on Server 2016)
Set-ItemProperty "IIS:\AppPools\DefaultAppPool" -Name "managedRuntimeVersion" -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\DefaultAppPool" -Name "enable32BitAppOnWin64" -Value $false

# Create application directory
$appPath = "C:\inetpub\wwwroot\PropertyManagement"
New-Item -ItemType Directory -Path $appPath -Force | Out-Null

Write-Log "=== Setup Complete ==="
Write-Log "IIS is running on port 80"
Write-Log "SQL Server Express is running on port 1433"
Write-Log "Web Deploy is available on port 8172"
Write-Log "Application directory: $appPath"
