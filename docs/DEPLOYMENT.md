# PropertyManager Legacy Deployment Guide

Deploy the PropertyManager .NET Framework 4.6.2 application to a Windows Server 2016 VM on Azure.

---

## 1. Prerequisites

- **Azure subscription** with permissions to create resource groups, VMs, and networking resources
- **Task** ([taskfile.dev](https://taskfile.dev)) — task runner for build and infrastructure commands
- **Terraform CLI** >= 1.5.0 ([install guide](https://developer.hashicorp.com/terraform/install))
- **Visual Studio 2018+ Enterprise** or standalone MSBuild (the build script expects `C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe`)
- **Azure CLI** authenticated (`az login`) — required for the AzureRM Terraform provider
- **RDP client** or **Web Deploy** (msdeploy.exe) for pushing artifacts to the VM

---

## 2. Infrastructure Provisioning

The Terraform code in `infrastructure/legacy/` creates:

| Resource | Purpose |
|----------|---------|
| Resource Group (auto-generated name) | Container for all resources |
| VNet + Subnet | Virtual network for the VM with auto-generated CIDR |
| Windows Server 2016 Datacenter VM (Standard_B2ms) | Hosts IIS + SQL Server Express |
| Public IP (Static) | Static IP for HTTP/HTTPS/RDP access |
| NSG | Allows HTTP (80), HTTPS (443), RDP (3389) — RDP restricted to deployer's IP |
| Custom Script Extension | Installs IIS, ASP.NET 4.6, Web Deploy 3.6, SQL Server 2016 Express |
| Data Disk (64 GB) | Dedicated SQL Server data file storage |

### Steps

```bash
# 1. Preview what will be created
task legacy:plan

# 2. Provision the VM (init + apply)
task legacy:up
```

Or specify a different region (default: `canadacentral`):

```bash
task legacy:up -- westus2
```

Provisioning takes ~15–20 minutes (SQL Server Express download/install is the bottleneck).

### Getting Your Credentials & Connection Info

After `task legacy:up` completes, run:

```bash
task legacy:creds
```

This displays:
- **RDP connection string** — use to connect to the VM via Remote Desktop
- **VM admin username** — default: `pmadmin`
- **VM admin password** — randomly generated, sensitive
- **SQL SA password** — randomly generated, sensitive

All credentials are stored as Terraform outputs. Save them securely!

### Accessing the Application

To open the website in your browser:

```bash
task legacy:browse
```

Or manually get the public IP:

```bash
cd infrastructure/legacy/
terraform output -raw vm_public_ip
```

Then visit `http://<public_ip>` in your browser.

---

## 3. Building the Application

From the repository root, run the build task using [Task](https://taskfile.dev):

```bash
task build
```

This performs four steps:

1. **Cleans** the `publish/` directory
2. **Restores** NuGet packages (packages.config-based restore)
3. **Builds** the solution in Release configuration (`src\PropertyManager.sln`)
4. **Publishes** the web project (`src\PropertyManager.Web\PropertyManager.Web.csproj`) to the `publish/` folder

Other useful commands:

```bash
task deploy   # Full build + deployment instructions
task --list   # Show all available tasks
```

The `publish/` folder contains the complete IIS-deployable application.

---

## 4. Deploying to the VM

### Option A: Web Deploy (Recommended)

First, get the VM's public IP and credentials:

```bash
task legacy:creds
```

Then deploy using msdeploy:

```powershell
$vmIp = "< from task legacy:creds >"
$username = "pmadmin"
$password = "< from task legacy:creds >"

msdeploy.exe `
  -verb:sync `
  -source:contentPath="publish/" `
  -dest:contentPath="C:\inetpub\wwwroot\PropertyManagement",computerName="https://${vmIp}:8172/msdeploy.axd",userName="$username",password="$password",authType="Basic" `
  -allowUntrusted
```

### Option B: RDP + File Copy

1. Get your RDP connection string: `task legacy:creds`
2. RDP into the VM and authenticate with `pmadmin` + password from `task legacy:creds`
3. Copy the contents of `publish/` to `C:\inetpub\wwwroot\PropertyManagement\`

### Token Replacement in web.config

After deploying, replace the placeholders in `web.config` with actual SQL Server values:

| Token | Replace With |
|-------|-------------|
| `#{DatabaseServer}#` | `localhost` (SQL is on the same VM) |
| `#{DatabaseName}#` | `PropertyManagement` |
| `#{DatabaseUser}#` | `sa` |
| `#{DatabasePassword}#` | Value from `task legacy:creds` (SQL Password) |

PowerShell example (run on the VM):

```powershell
$webConfig = "C:\inetpub\wwwroot\PropertyManagement\web.config"
$sqlPassword = "YOUR_SQL_SA_PASSWORD"  # From task legacy:creds

$content = Get-Content $webConfig -Raw
$content = $content -replace '#{DatabaseServer}#', 'localhost'
$content = $content -replace '#{DatabaseName}#', 'PropertyManagement'
$content = $content -replace '#{DatabaseUser}#', 'sa'
$content = $content -replace '#{DatabasePassword}#', $sqlPassword
Set-Content $webConfig $content
```

---

## 5. Database Setup

The application uses **Entity Framework 6 Code First** with `AutomaticMigrationsEnabled = true`.

- **No manual migration steps are required.** The database schema is created automatically on the first HTTP request that triggers a database call.
- The `PropertyManagement` database is pre-created by the Terraform setup script (empty shell).
- EF6 will create all tables and seed initial data on first run.
- Seed data includes sample properties, tenants, and lookup values.

If you need to reset the database, drop it and let EF recreate:

```sql
-- Run on the VM via SSMS or sqlcmd
DROP DATABASE PropertyManagement;
```

---

## 6. Verification

After deployment, verify the application is running:

```powershell
# Get the application URL
$appUrl = task legacy:browse  # This opens it in a browser

# Or manually verify via PowerShell
$vmIp = "< from task legacy:creds >"
Invoke-WebRequest -Uri "http://${vmIp}" -UseBasicParsing | Select-Object StatusCode
```

Expected results:
- HTTP 200 on the root URL
- First request may be slow (~10–30s) as IIS warms up and EF creates the database schema

---

## 7. Troubleshooting

### RDP / Network Issues

- Check the NSG rules in the Azure portal — HTTP (80), HTTPS (443), and RDP (3389) must be allowed inbound.
- RDP is restricted to your current IP (detected at provisioning time). If you connect from a different network, you'll need to update the NSG rule.
- Verify connectivity: `Test-NetConnection <vm_ip> -Port 3389`

### Connection String & SQL Issues

- Verify token replacement was done in `web.config` — search for any remaining `#{` placeholders.
- Test SQL connectivity from the VM: `sqlcmd -S localhost -U sa -P <password> -Q "SELECT 1"`
- Ensure SQL Server service is running: `Get-Service MSSQLSERVER`
- Check TCP/IP is enabled: SQL Server Configuration Manager → Protocols → TCP/IP must be Enabled.

### IIS App Pool .NET version mismatch

- The DefaultAppPool must use **.NET CLR v4.0** (which covers .NET Framework 4.6.2).
- Check: `Get-ItemProperty "IIS:\AppPools\DefaultAppPool" -Name managedRuntimeVersion`
- Fix: `Set-ItemProperty "IIS:\AppPools\DefaultAppPool" -Name managedRuntimeVersion -Value "v4.0"`

### Application errors (500)

- Check IIS logs: `C:\inetpub\logs\LogFiles\W3SVC1\`
- Enable detailed errors in web.config: set `<customErrors mode="Off" />`
- Check Event Viewer → Windows Logs → Application for .NET exceptions.

### VM setup script didn't complete

- RDP into the VM and check the log file: `Get-Content C:\setup-log.txt`
- Re-run the script manually if needed: `C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\*\Downloads\0\setup-iis-sql.ps1`

---

## 8. Cleanup & Destruction

To destroy all Azure resources:

```bash
task legacy:down
```

This:
1. Deletes the resource group (and all contained resources)
2. Cleans up local Terraform state files
