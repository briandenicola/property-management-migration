# Theo — History

## Learnings

### 2026-04-30T17:33:47Z — Azure Migrate Demo IP Package

Created the full Azure Migrate demo intellectual property package — 6 files covering the complete "IIS VM → App Service" demo workflow.

**Files created:**

- `docs/demo-guide.md` — Narrated step-by-step demo script with timing marks (18 min total across 4 acts), exact commands/clicks, inline talking points, day-before prep checklist, and fallback procedures at every step.
- `docs/talking-points.md` — Client-facing value propositions (eliminate toil, pay-per-use, monitoring, SLA, security), before/after comparison table, TCO discussion (VM true cost vs App Service), common objections + responses, and 30-second elevator pitch.
- `scripts/demo/assess.ps1` — Day-before assessment automation: logs in, resolves legacy VM from Terraform outputs, creates/reuses Azure Migrate project, installs `az migrate` extension if needed, generates assessment metadata JSON, exports report to `docs/assessment-report.json`.
- `scripts/demo/migrate.ps1` — Fallback migration pipeline: NuGet restore → MSBuild compile → MSBuild publish → zip package → `az webapp deploy` (zip deploy) → connection string update → restart → health check. Supports `-DryRun`, `-SkipBuild`, and `-ConnectionStringOnly` modes.
- `scripts/demo/validate.ps1` — Post-migration validation suite: HTTP health (root URL), API endpoint, DB connectivity (via API response), Blob Storage access (attachment endpoint), response time comparison (legacy vs modern, 3 samples), and feature smoke test (create + read-back property). Passes/Fails/Warns with summary table.
- `scripts/demo/compare.ps1` — Before/after comparison report: itemized monthly cost breakdown (compute, DB, storage, backup, monitoring, SSL, ops labor), feature comparison table (20+ dimensions), SLA comparison, and optional JSON export. All prices are Canada Central retail estimates with disclaimer.

**Key design decisions:**
- All scripts auto-detect Terraform outputs (resource group, App Service name, SQL connection string) from `infrastructure/azure/` — no hardcoded names
- Scripts use consistent color output and Unicode progress indicators (▶ ✓ ✗ ⚠) for demo visibility
- MSBuild path matches `Taskfile.yaml` env var (`C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe`)
- `assess.ps1` is idempotent — safe to re-run multiple times
- `migrate.ps1` `-DryRun` mode validates the full build pipeline without touching Azure — ideal for day-before verification
- Subscription hardcoded as default: `ccfc5dda-43af-4b5e-8cc2-1dda18f2382e` (overridable via parameter)

**Demo structure:**
- Act 1 (3 min): Legacy app on IIS, RDP into VM
- Act 2 (5 min): Azure Migrate assessment results in portal
- Act 3 (5 min): Migration Assistant live + scripted fallback
- Act 4 (5 min): App on App Service + monitoring, autoscale, compare report

### 2026-04-30T16:48:02Z — Storage Account AAD Auth (Subscription Policy Fix)

Azure subscription has a policy that blocks key-based authentication on storage accounts (`KeyBasedAuthenticationNotPermitted`). Fixed the Terraform config to use Azure AD for all storage data plane operations:

**Changes made:**
- `infrastructure/azure/providers.tf` — Added `storage_use_azuread = true` to the `azurerm` provider block. This tells the Terraform provider to use Azure AD (not shared keys) for storage data plane operations like managing containers.
- `infrastructure/azure/main.tf`:
  - Added `shared_access_key_enabled = false` on `azurerm_storage_account.this` — explicitly acknowledges the subscription policy and prevents Terraform from attempting key-based access.
  - Replaced `BlobStorage__ConnectionString` app setting (which used `primary_connection_string`, a key-based credential) with `BlobStorage__ServiceUri` pointing to `primary_blob_endpoint`. The app will use managed identity + DefaultAzureCredential to access blob storage.
  - Added `azurerm_role_assignment.app_storage_blob` — grants the App Service's system-assigned managed identity "Storage Blob Data Contributor" on the storage account, enabling token-based blob read/write.

**Key insight:** When `shared_access_key_enabled = false` (or a policy enforces it), the provider cannot use keys for data plane ops. You MUST set `storage_use_azuread = true` at the provider level, otherwise `azurerm_storage_container` and similar data plane resources will fail with 403.

**App-side impact:** The application code must use `DefaultAzureCredential` (or `ManagedIdentityCredential`) with the blob service URI instead of a connection string. Karl needs to ensure the blob storage client is configured for managed identity auth.

### 2026-04-30T16:41:38Z — Documentation Audit & Update

Updated all deployment documentation to reflect the current state of the infrastructure (as of 2026-04-30):

**Files updated:**
- `docs/DEPLOYMENT.md` — Updated to use `task legacy:plan`, `task legacy:up`, and `task legacy:creds` instead of old `task plan`/`task up`. Removed references to terraform.tfvars files (now auto-generated). Updated Terraform outputs to match actual code (e.g., `vm_public_ip`, `rdp_connection_string`, `iis_url`).
- `infrastructure/legacy/README.md` — Removed tfvars.example references. Updated to explain auto-generated random naming convention (`{pet}-{id}_rg`). Documented that passwords are randomly generated, not user-provided. Added both Task-based and manual Terraform usage examples.
- `infrastructure/azure/README.md` — Same pattern: removed tfvars, updated output names, documented random naming, added both Task and manual usage.
- `docs/iis-setup.md` — Updated platform details to Windows Server 2016, IIS 10.0, .NET Framework 4.6.2 (from old 2012 R2/IIS 8.5/4.6.1). Added note that infrastructure is auto-provisioned by Terraform Custom Script Extension. Updated timestamp.

**Key changes across all docs:**
1. **No more terraform.tfvars** — All sensitive values (admin password, SQL SA password) are randomly generated via `random_password` resources. No manual password setup required.
2. **Resource naming** — Changed from static names (`rg-property-mgmt-legacy`) to random auto-generated names (`{pet}-{id}_rg`) to avoid conflicts when multiple teams deploy.
3. **Task command references** — Updated to use the current Taskfile includes: `task legacy:up`, `task legacy:plan`, `task legacy:down`, `task legacy:creds`, `task legacy:browse` (not old `task up`/`task plan`).
4. **Terraform outputs** — Updated to match actual outputs.tf: `vm_public_ip`, `rdp_connection_string`, `vm_admin_username`, `vm_admin_password`, `sql_sa_password`, `iis_url` (not old `vm_dns_name`, `app_url`, `web_deploy_url`).
5. **Credentials flow** — Clarified: `task legacy:creds` shows all credentials, passwords, and RDP string. No need to manually run terraform output commands.

**Why this matters:**
- Docs were out of sync with actual Terraform code, making deployments confusing.
- Random naming & auto-generated passwords align with security best practices (no credentials in source control).
- Task-based commands make the deployment process simpler and more reproducible.

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

- App name is **PropertyManager** (formerly PropertyPro), per `docs/architecture-legacy.md`
- Stack: .NET Framework 4.6.2, Web API 2, EF 6.1.3, AngularJS 1.5.x, IIS 10.0, Windows Server 2016
- App pool must use **Integrated Pipeline** mode — OWIN/Katana (`Microsoft.Owin.Host.SystemWeb`) requires it; Classic mode causes startup exception
- Upload limits must be set in **three places** consistently: `maxRequestLength` (KB, in `<httpRuntime>`), `maxAllowedContentLength` (bytes, in `<requestFiltering>`), and `MaxFileSizeBytes` app setting. For 25MB: 25600 KB / 26214400 bytes
- **WebDAV module must be explicitly removed** — it intercepts PUT/DELETE verbs before they reach Web API, causing 405 errors
- Production credentials are never in web.config source control; use `aspnet_regiis -pe` encryption or IIS Manager Connection Strings UI
- `web.Release.config` XDT transform handles: `debug` attribute removal, `customErrors mode="On"`, CORS origin lockdown, connection string swap, Swagger disable
- AngularJS HTML5 pushState routing requires URL Rewrite 2.x module + a rewrite rule in web.config
- App pool identity needs **Modify** rights on `App_Data\Uploads\Temp` for file upload buffering
- Deployment style is Web Deploy or xcopy/robocopy — always snapshot before deploying for rollback.

**Key file paths created:**
- `src/PropertyManager.Web/web.config` — full IIS config with inline history comments
- `src/PropertyManager.Web/web.Release.config` — XDT production transform
- `docs/iis-setup.md` — complete IIS setup and deployment guide

### 2026-04-29T21:01:36Z — Terraform Infrastructure-as-Code

Created two Terraform configurations for the migration demo:

**Legacy VM (`infrastructure/legacy/`):**
- Windows Server 2016 Datacenter VM (Standard_B2ms)
- NSG with HTTP/HTTPS open, RDP restricted to deployer's current IP (auto-detected)
- 64 GB Premium data disk for SQL Server data files
- Custom Script Extension runs `scripts/setup-legacy-server.ps1`
- Setup script installs IIS + ASP.NET 4.6, SQL Server 2016 Express, creates PropertyManager DB, configures IIS site
- **Random naming:** `{pet}-{id}_rg`, `{pet}-{id}-vm`, etc.
- **Random passwords:** Admin and SQL SA passwords auto-generated (16 chars, special=true)
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
- Random naming used to avoid conflicts across multiple deployments
- Passwords generated by Terraform — no tfvars files for secrets
- Tags: project, components, deployed on timestamp
- Remote state backend blocks included but commented out
- Storage account name strips hyphens (Azure requirement)
- SQL connection string uses SQL auth (not AAD) — matches legacy app's connection pattern

**Key file paths:**
- `infrastructure/legacy/` — providers.tf, variables.tf, main.tf, outputs.tf, README.md
- `infrastructure/legacy/scripts/setup-legacy-server.ps1` — VM bootstrap script
- `infrastructure/azure/` — providers.tf, variables.tf, main.tf, outputs.tf, README.md
- `.gitignore` — updated with Terraform patterns (*.tfstate, .terraform/, *.tfvars)

### 2026-04-29T20:55:27Z — Scribe: Decisions Archived
- IIS configuration decision merged and consolidated in decisions.md
- Orchestration log created at `.squad/orchestration-log/2026-04-29T20-40-56-theo.md`
- Team decisions now available for all agents to reference

### 2026-04-29T21:02:29Z — Scribe: Inbox Merged
- Theo's .gitignore and terraform decisions merged into Active Decisions
- Inbox cleared of 2 processed files
- Ready for team visibility
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
