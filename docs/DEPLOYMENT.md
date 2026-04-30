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

The Terraform code in `infrastructure/` creates:

| Resource | Purpose |
|----------|---------|
| Resource Group (`rg-property-mgmt-legacy`) | Container for all resources |
| VNet `vnet-property-mgmt` / Subnet `snet-default` | 10.0.0.0/16 network with 10.0.1.0/24 subnet |
| Windows Server 2016 Datacenter VM (`vm-propmgmt`, Standard_B2ms) | Hosts IIS + SQL Server Express |
| Public IP with DNS label | Static IP, FQDN: `<dns_label_prefix>.<region>.cloudapp.azure.com` |
| NSG (`nsg-property-mgmt-vm`) | Allows HTTP (80), HTTPS (443), RDP (3389), Web Deploy (8172) |
| Custom Script Extension | Installs IIS, ASP.NET 4.5, Web Deploy 3.6, SQL Server 2016 Express |

### Steps

```bash
# 1. Create your variables file
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
# Edit terraform.tfvars — set strong passwords for vm_admin_password and sql_sa_password
```

```bash
# 2. Preview what will be created
task plan

# 3. Provision the VM (init + apply)
task up
```

Or specify a different region:

```bash
task up -- westus2
```

Provisioning takes ~15–20 minutes (SQL Server Express download/install is the bottleneck).

### Outputs

After `task up` completes, note these values:

```bash
cd infrastructure/
terraform output vm_public_ip        # Static public IP
terraform output vm_dns_name         # FQDN for the VM
terraform output app_url             # http://<fqdn>
terraform output web_deploy_url      # https://<fqdn>:8172/msdeploy.axd
terraform output vm_admin_username   # Default: pmadmin
terraform output -raw sql_connection_string  # Connection string (sensitive)
```

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

```powershell
$vmFqdn = terraform -chdir=infrastructure output -raw vm_dns_name

msdeploy.exe `
  -verb:sync `
  -source:contentPath="publish/" `
  -dest:contentPath="C:\inetpub\wwwroot\PropertyManagement",computerName="https://${vmFqdn}:8172/msdeploy.axd",userName="pmadmin",password="<vm_admin_password>",authType="Basic" `
  -allowUntrusted
```

### Option B: RDP + File Copy

1. RDP into the VM: `mstsc /v:<vm_public_ip>`  (user: `pmadmin`)
2. Copy the contents of `publish/` to `C:\inetpub\wwwroot\PropertyManagement\`

### Token Replacement in web.config

After deploying, replace the placeholders in `web.config` with actual SQL Server values:

| Token | Replace With |
|-------|-------------|
| `#{DatabaseServer}#` | `localhost` (SQL is on the same VM) |
| `#{DatabaseName}#` | `PropertyManagement` |
| `#{DatabaseUser}#` | `sa` |
| `#{DatabasePassword}#` | Value of `sql_sa_password` from your tfvars |

PowerShell example (run on the VM):

```powershell
$webConfig = "C:\inetpub\wwwroot\PropertyManagement\web.config"
$content = Get-Content $webConfig -Raw
$content = $content -replace '#{DatabaseServer}#', 'localhost'
$content = $content -replace '#{DatabaseName}#', 'PropertyManagement'
$content = $content -replace '#{DatabaseUser}#', 'sa'
$content = $content -replace '#{DatabasePassword}#', 'YOUR_SQL_SA_PASSWORD'
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
$appUrl = terraform -chdir=infrastructure output -raw app_url

# 1. Check the site responds
Invoke-WebRequest -Uri $appUrl -UseBasicParsing | Select-Object StatusCode

# 2. Verify the dashboard loads (should return 200)
Invoke-WebRequest -Uri "$appUrl/Dashboard" -UseBasicParsing | Select-Object StatusCode

# 3. Check API endpoints respond
Invoke-WebRequest -Uri "$appUrl/api/properties" -UseBasicParsing | Select-Object StatusCode
```

Expected results:
- HTTP 200 on the root URL and `/Dashboard`
- HTTP 200 with JSON payload on `/api/properties`
- First request may be slow (~10–30s) as EF creates the database schema

---

## 7. Troubleshooting

### NSG / Firewall blocking traffic

- Verify NSG rules in the Azure portal (HTTP 80, HTTPS 443, RDP 3389, Web Deploy 8172 must be allowed inbound).
- On the VM, check Windows Firewall: `Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' }`
- The setup script creates firewall rules for ports 80, 443, 1433, and 8172. If they're missing, re-run the rules from `infrastructure/scripts/setup-iis-sql.ps1`.

### Connection string errors

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

### Web Deploy fails

- Ensure the Web Management Service is running: `Get-Service WMSVC`
- Verify port 8172 is reachable: `Test-NetConnection <vm_ip> -Port 8172`
- Check credentials match the VM admin account (`pmadmin`).

### VM setup script didn't complete

- RDP into the VM and check the log file: `Get-Content C:\setup-log.txt`
- Re-run the script manually if needed: `C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\*\Downloads\0\setup-iis-sql.ps1`
