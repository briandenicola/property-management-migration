# Theo — History

## Learnings

### 2026-04-29T20:58:45Z — .gitignore and Binary Cleanup

- Added a comprehensive `.NET Framework 4.6 / Visual Studio 2015`-era `.gitignore` covering bin/, obj/, packages/, .vs/, *.suo, *.user, ReSharper, NCrunch, SQL files, publish artifacts, and all common 2015-era tooling noise.
- Preserved existing squad-specific entries (`.squad/` runtime dirs, `.squad-workstream`) at the bottom of the updated file.
- Ran `git rm -r --cached src/packages/` — removed 85 tracked NuGet package files (EntityFramework, WebAPI, OWIN, Newtonsoft, Identity) from the index. Files remain on disk for local developer builds.
- Ran `git rm -r --cached src/PropertyManager.Web/obj/` — removed 1 tracked MSBuild artifact (`FileListAbsolute.txt`).
- Other bin/obj dirs (Core, Data) were not tracked — no action needed there.
- Committed and pushed to origin master: `chore: add .gitignore and remove tracked binaries`.

**Pattern noted:** In legacy packages.config NuGet workflow, packages/ is frequently accidentally committed on first setup because `.gitignore` is added after the initial commit. Always check `git ls-files src/packages/` before assuming it's clean.

- Project: Property management app migration to Azure
- Legacy: IIS on Windows, SQL Server on-prem, blobs in database
- Target: Azure App Service, Azure SQL, Azure Blob Storage
- User: Brian

### 2026-04-29 — IIS Legacy Deployment Configuration

- App name is **PropertyPro** (not PropertyManager), per `docs/architecture-legacy.md`
- Stack: .NET Framework 4.6.1, Web API 2, EF 6.1.3, AngularJS 1.5.x, IIS 8.5, Windows Server 2012 R2
- App pool must use **Integrated Pipeline** mode — OWIN/Katana (`Microsoft.Owin.Host.SystemWeb`) requires it; Classic mode causes startup exception
- Upload limits must be set in **three places** consistently: `maxRequestLength` (KB, in `<httpRuntime>`), `maxAllowedContentLength` (bytes, in `<requestFiltering>`), and `MaxFileSizeBytes` app setting. For 25MB: 25600 KB / 26214400 bytes
- **WebDAV module must be explicitly removed** — it intercepts PUT/DELETE verbs before they reach Web API, causing 405 errors
- Production credentials are never in web.config source control; use `aspnet_regiis -pe` encryption or IIS Manager Connection Strings UI
- `web.Release.config` XDT transform handles: `debug` attribute removal, `customErrors mode="On"`, CORS origin lockdown, connection string swap, Swagger disable
- AngularJS HTML5 pushState routing requires URL Rewrite 2.x module + a rewrite rule in web.config
- App pool identity needs **Modify** rights on `App_Data\Uploads\Temp` for file upload buffering
- Deployment style is xcopy/robocopy — no MSDeploy. Always snapshot before deploying for rollback.

**Key file paths created:**
- `src/PropertyManager.Web/web.config` — full IIS config with inline history comments
- `src/PropertyManager.Web/web.Release.config` — XDT production transform
- `docs/iis-setup.md` — complete IIS setup and deployment guide

### 2026-04-29T21:01:36Z — Terraform Infrastructure-as-Code

Created two Terraform configurations for the migration demo:

**Legacy VM (`infrastructure/legacy/`):**
- Windows Server 2016 Datacenter VM (Standard_D2s_v3)
- NSG with HTTP/HTTPS open, RDP restricted to configurable IP
- 64 GB Premium data disk for SQL Server data files
- Custom Script Extension runs `scripts/setup-legacy-server.ps1`
- Setup script installs IIS + ASP.NET 4.6, SQL Server 2016 Express, creates PropertyManager DB, configures IIS site
- Uses `azurerm` provider ~> 3.80, validated successfully

**Modern PaaS (`infrastructure/azure/`):**
- App Service Plan (S1 Windows) + Windows Web App (.NET Framework 4.6)
- Azure SQL Server + Database (configurable SKU, default S0)
- Storage Account + `attachments` blob container with CORS
- Application Insights + Log Analytics workspace
- Connection strings and blob config wired into App Service app_settings
- SQL firewall rules for Azure services + configurable dev IPs
- System-Assigned Managed Identity enabled on App Service

**Architecture decisions:**
- Provider pinned to `~> 3.80` (latest stable 3.x line)
- Naming convention: `pm-legacy-*` / `pm-modern-*`
- Tags: `project=property-management`, `environment=legacy|modern`, `managed_by=terraform`
- Remote state backend blocks included but commented out
- Storage account name strips hyphens (Azure requirement)
- SQL connection string uses SQL auth (not AAD) — matches legacy app's connection pattern

**Key file paths:**
- `infrastructure/legacy/` — providers.tf, variables.tf, main.tf, outputs.tf, terraform.tfvars.example, README.md
- `infrastructure/legacy/scripts/setup-legacy-server.ps1` — VM bootstrap script
- `infrastructure/azure/` — providers.tf, variables.tf, main.tf, outputs.tf, terraform.tfvars.example, README.md
- `.gitignore` — updated with Terraform patterns (*.tfstate, .terraform/, *.tfvars)

### 2026-04-29T20:55:27Z — Scribe: Decisions Archived
- IIS configuration decision merged and consolidated in decisions.md
- Orchestration log created at `.squad/orchestration-log/2026-04-29T20-40-56-theo.md`
- Team decisions now available for all agents to reference

### 2026-04-29T21:02:29Z — Scribe: Inbox Merged
- Theo's .gitignore and terraform decisions merged into Active Decisions
- Inbox cleared of 2 processed files
- Ready for team visibility
