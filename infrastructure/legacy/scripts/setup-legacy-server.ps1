<#
.SYNOPSIS
    Configures a Windows Server 2016 VM as a legacy PropertyPro hosting environment.
    Installs IIS with ASP.NET 4.6, SQL Server 2016 Express, and creates the PropertyManager database.

.PARAMETER SqlSaPassword
    Password for the SQL Server SA account.

.PARAMETER AdminUsername
    Local administrator username (used for SQL Server admin mapping).

.NOTES
    This script is executed by the Azure Custom Script Extension during VM provisioning.
    It assumes a raw data disk is attached at LUN 0 for SQL Server data files.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SqlSaPassword,

    [Parameter(Mandatory = $true)]
    [string]$AdminUsername
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\WindowsTemp\setup-legacy-server.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Output $Message
}

# ============================================================
# 1. Initialize and format the data disk (F: drive)
# ============================================================
Write-Log "Initializing data disk..."

$disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } | Select-Object -First 1
if ($disk) {
    $disk | Initialize-Disk -PartitionStyle MBR -PassThru |
        New-Partition -UseMaximumSize -DriveLetter F |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLData" -Confirm:$false
    Write-Log "Data disk formatted as F: drive"
} else {
    Write-Log "No raw disk found — skipping disk initialization"
}

# Create SQL Server data directories
New-Item -ItemType Directory -Path "F:\SQLData" -Force | Out-Null
New-Item -ItemType Directory -Path "F:\SQLLog" -Force | Out-Null
New-Item -ItemType Directory -Path "F:\SQLBackup" -Force | Out-Null
Write-Log "SQL data directories created on F: drive"

# ============================================================
# 2. Install IIS with ASP.NET 4.6
# ============================================================
Write-Log "Installing IIS and ASP.NET features..."

$features = @(
    "Web-Server",
    "Web-WebServer",
    "Web-Common-Http",
    "Web-Static-Content",
    "Web-Default-Doc",
    "Web-Dir-Browsing",
    "Web-Http-Errors",
    "Web-App-Dev",
    "Web-Asp-Net45",
    "Web-Net-Ext45",
    "Web-ISAPI-Ext",
    "Web-ISAPI-Filter",
    "Web-Health",
    "Web-Http-Logging",
    "Web-Log-Libraries",
    "Web-Request-Monitor",
    "Web-Security",
    "Web-Filtering",
    "Web-Basic-Auth",
    "Web-Windows-Auth",
    "Web-Mgmt-Tools",
    "Web-Mgmt-Console",
    "NET-Framework-45-Core",
    "NET-Framework-45-ASPNET",
    "NET-WCF-Services45",
    "NET-WCF-HTTP-Activation45"
)

Install-WindowsFeature -Name $features -IncludeManagementTools
Write-Log "IIS and ASP.NET 4.6 features installed"

# Install URL Rewrite Module (required for AngularJS HTML5 routing)
Write-Log "Installing URL Rewrite Module..."
$rewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
$rewriteMsi = "C:\WindowsTemp\rewrite_amd64.msi"
Invoke-WebRequest -Uri $rewriteUrl -OutFile $rewriteMsi -UseBasicParsing
Start-Process msiexec.exe -ArgumentList "/i `"$rewriteMsi`" /qn" -Wait -NoNewWindow
Write-Log "URL Rewrite Module installed"

# ============================================================
# 3. Install SQL Server 2016 Express
# ============================================================
Write-Log "Downloading SQL Server 2016 Express..."

$sqlExpressUrl = "https://download.microsoft.com/download/9/0/7/907AD35F-9F9C-43A5-9789-52470555DB90/ENU/SQLEXPR_x64_ENU.exe"
$sqlInstaller = "C:\WindowsTemp\SQLEXPR_x64_ENU.exe"
Invoke-WebRequest -Uri $sqlExpressUrl -OutFile $sqlInstaller -UseBasicParsing

Write-Log "Installing SQL Server 2016 Express..."

# Extract and run setup
Start-Process -FilePath $sqlInstaller -ArgumentList "/qs /x:C:\WindowsTemp\SQLSetup" -Wait -NoNewWindow

$setupArgs = @(
    "/Q",
    "/ACTION=Install",
    "/FEATURES=SQLEngine",
    "/INSTANCENAME=SQLEXPRESS",
    "/SQLSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`"",
    "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`"",
    "/SECURITYMODE=SQL",
    "/SAPWD=`"$SqlSaPassword`"",
    "/SQLUSERDBDIR=`"F:\SQLData`"",
    "/SQLUSERDBLOGDIR=`"F:\SQLLog`"",
    "/SQLBACKUPDIR=`"F:\SQLBackup`"",
    "/TCPENABLED=1",
    "/IACCEPTSQLSERVERLICENSETERMS"
)

Start-Process -FilePath "C:\WindowsTemp\SQLSetup\setup.exe" -ArgumentList ($setupArgs -join " ") -Wait -NoNewWindow
Write-Log "SQL Server 2016 Express installed"

# Enable TCP/IP and set port 1433
Write-Log "Configuring SQL Server network protocols..."
Import-Module "sqlps" -DisableNameChecking -ErrorAction SilentlyContinue

# Start SQL Server service
Set-Service -Name "MSSQL`$SQLEXPRESS" -StartupType Automatic
Start-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue
Start-Service -Name "SQLBrowser" -ErrorAction SilentlyContinue
Set-Service -Name "SQLBrowser" -StartupType Automatic

# ============================================================
# 4. Create the PropertyManager database
# ============================================================
Write-Log "Creating PropertyManager database..."

$sqlCmd = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'PropertyManager')
BEGIN
    CREATE DATABASE [PropertyManager]
    ON PRIMARY (
        NAME = N'PropertyManager',
        FILENAME = N'F:\SQLData\PropertyManager.mdf',
        SIZE = 64MB, FILEGROWTH = 64MB
    )
    LOG ON (
        NAME = N'PropertyManager_log',
        FILENAME = N'F:\SQLLog\PropertyManager_log.ldf',
        SIZE = 32MB, FILEGROWTH = 32MB
    )
END
GO

USE [PropertyManager]
GO

-- Create the application login
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'PropertyProApp')
BEGIN
    CREATE LOGIN [PropertyProApp] WITH PASSWORD = '$SqlSaPassword', DEFAULT_DATABASE = [PropertyManager]
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'PropertyProApp')
BEGIN
    CREATE USER [PropertyProApp] FOR LOGIN [PropertyProApp]
    ALTER ROLE [db_owner] ADD MEMBER [PropertyProApp]
END
GO
"@

# Wait for SQL Server to be ready
$attempts = 0
do {
    $attempts++
    Start-Sleep -Seconds 5
    $sqlReady = sqlcmd -S ".\SQLEXPRESS" -U sa -P $SqlSaPassword -Q "SELECT 1" 2>$null
} while (-not $sqlReady -and $attempts -lt 12)

sqlcmd -S ".\SQLEXPRESS" -U sa -P $SqlSaPassword -Q $sqlCmd
Write-Log "PropertyManager database created"

# ============================================================
# 5. Configure IIS site for PropertyPro
# ============================================================
Write-Log "Configuring IIS site..."

$sitePath = "C:\inetpub\PropertyPro"
New-Item -ItemType Directory -Path $sitePath -Force | Out-Null
New-Item -ItemType Directory -Path "$sitePath\App_Data\Uploads\Temp" -Force | Out-Null

# Create application pool
Import-Module WebAdministration

if (-not (Test-Path "IIS:\AppPools\PropertyPro")) {
    New-WebAppPool -Name "PropertyPro"
}

Set-ItemProperty "IIS:\AppPools\PropertyPro" -Name "managedRuntimeVersion" -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\PropertyPro" -Name "managedPipelineMode" -Value "Integrated"
Set-ItemProperty "IIS:\AppPools\PropertyPro" -Name "startMode" -Value "AlwaysRunning"

# Remove default site and create PropertyPro site
Remove-WebSite -Name "Default Web Site" -ErrorAction SilentlyContinue

if (-not (Get-WebSite -Name "PropertyPro" -ErrorAction SilentlyContinue)) {
    New-WebSite -Name "PropertyPro" `
        -PhysicalPath $sitePath `
        -ApplicationPool "PropertyPro" `
        -Port 80 `
        -Force
}

# Grant app pool identity write access to upload temp folder
$acl = Get-Acl "$sitePath\App_Data\Uploads\Temp"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "IIS AppPool\PropertyPro", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl -Path "$sitePath\App_Data\Uploads\Temp" -AclObject $acl

Write-Log "IIS site 'PropertyPro' configured on port 80"

# ============================================================
# 6. Create a placeholder index page
# ============================================================
$placeholder = @"
<!DOCTYPE html>
<html>
<head><title>PropertyPro - Legacy Server</title></head>
<body>
    <h1>PropertyPro Legacy Server</h1>
    <p>IIS is running. Deploy the application to C:\inetpub\PropertyPro to get started.</p>
    <p>SQL Server Express: .\SQLEXPRESS</p>
    <p>Database: PropertyManager</p>
</body>
</html>
"@
$placeholder | Out-File -FilePath "$sitePath\index.html" -Encoding UTF8

# ============================================================
# 7. Windows Firewall rules for SQL Server
# ============================================================
Write-Log "Configuring Windows Firewall..."
New-NetFirewallRule -DisplayName "SQL Server Express" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
New-NetFirewallRule -DisplayName "SQL Server Browser" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action Allow

Write-Log "=========================================="
Write-Log "Legacy server setup complete!"
Write-Log "  IIS Site: http://localhost (PropertyPro)"
Write-Log "  SQL Server: .\SQLEXPRESS"
Write-Log "  Database: PropertyManager"
Write-Log "  Data Disk: F:\SQLData"
Write-Log "=========================================="
