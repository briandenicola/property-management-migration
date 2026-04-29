# Squad Decisions

## Active Decisions

### 2026-04-29T20:39:45Z: Migration target is PaaS (Azure App Services)
**By:** Brian (via Copilot)  
**What:** Migration target is lift-and-shift to PaaS — Azure App Services on Windows and Azure SQL Server. NOT to VMs.  
**Why:** User request — the demo narrative is about going from IIS/on-prem directly to PaaS, not an intermediate VM step.

### 2026-04-29T20:47:35Z: Test locally first, no cloud provisioning until app works
**By:** Brian (via Copilot)  
**What:** Validate the legacy app works locally before demonstrating the lift-and-shift to Azure.  
**Why:** User request — test locally first, then migrate.

### 2026-04-29T20:40:56.058Z: Legacy Application Architecture Blueprint
**Author:** McClane  
**Status:** Accepted  
**Scope:** Full team  

The legacy PropertyPro application architecture is defined in `docs/architecture-legacy.md`. This blueprint guides Karl, Argyle, and Theo.

**Key Architecture Points:**
- Solution name: `PropertyManager.sln` (NOT PropertyPro.sln) with `PropertyManager.Web` project
- Stack: .NET Framework 4.6.1, Web API 2, EF6, AngularJS 1.6, Bootstrap 3, IIS
- Frontend location: Inside Web project at `/app` (no separate SPA build)
- File storage: `varbinary(MAX)` in SQL Server (intentional anti-pattern for migration story)
- Auth: Cookie-based via ASP.NET Identity
- DI: Unity container (minimal, intentionally inconsistent)
- Domain: Properties → Tenants → MaintenanceRequests → Attachments
- Status workflow: Open → InProgress → Completed → Closed
- Must feel authentically ~2015 era for migration demo impact
- Blobs-in-SQL is the primary anti-pattern driving Azure Blob Storage migration

**Team Impact:**
- Karl: Build backend per architecture doc sections 7.1–7.7
- Argyle: Build frontend per sections 8.1–8.6
- Theo: IIS hosting per section 9

### 2026-04-29T20:40:56.058Z: Backend Structure (Three-Project Pattern)
**Author:** Karl  
**Status:** Accepted

Three-project structure rooted at `src/PropertyManager.sln`:
- `PropertyManager.Web`: ASP.NET Web API 2 controllers, DTOs, filters, app startup
- `PropertyManager.Data`: EF6 entities, DbContext, repositories, EF6 migrations
- `PropertyManager.Core`: Business services and interfaces

**Rationale:** Preserves authentic .NET Framework 4.6-era layering while enabling clear migration seams to .NET 8 and EF Core. Keeps blob storage concerns isolated. Supports API contract stability for frontend coordination.

**Impact:**
- Explicit ownership boundaries
- File upload/download stores bytes in SQL `varbinary(max)` for legacy fidelity
- Future migration can lift services/repositories with minimal controller changes

### 2026-04-29T20:40:56.058Z: Frontend Structure (Raw AngularJS 1.6)
**Author:** Argyle  
**Status:** Accepted

Implement legacy frontend as raw-file AngularJS 1.6 app under `src/PropertyManager.Web/app/`:
- Manually ordered script tags in `index.html`
- UI-Router state navigation
- Controller/service/directive separation
- Bootstrap 3.3.7-era templates
- No webpack/gulp/grunt/npm frontend pipeline

**Rationale:** Matches architecture blueprint, stays authentically ~2015, keeps migration-ready boundaries (API calls isolated in services, legacy UI in controllers/views).

**Key Paths:**
- `src/PropertyManager.Web/app/index.html`
- `src/PropertyManager.Web/app/app.js`
- `src/PropertyManager.Web/app/controllers/controllers.js`
- `src/PropertyManager.Web/app/services/*.js`
- `src/PropertyManager.Web/app/views/*.html`
- `src/PropertyManager.Web/app/css/site.css`

### 2026-04-29T20:40:56.058Z: IIS Legacy Configuration Patterns
**Author:** Theo  
**Status:** Accepted

**1. Integrated Pipeline Mode (not Classic)**
- App pool uses Integrated Pipeline
- OWIN/Katana requires Integrated mode; Classic causes startup exception

**2. Upload Size: 25MB Hard Limit**
- `maxRequestLength="25600"` (KB) in `<httpRuntime>`
- `maxAllowedContentLength="26214400"` (bytes) in IIS `<requestFiltering>`
- `MaxFileSizeBytes="26214400"` app setting
- Rationale: Contractor PDFs and multi-photo reports hit 15–20MB; 25MB gives headroom without excessive SQL Server blob growth

**3. Production Credentials: Never in Source Control**
- Production connection strings set via `aspnet_regiis -pe` or IIS Manager
- `web.Release.config` contains only placeholders
- Rationale: Security baseline

**4. WebDAV Module: Explicitly Removed**
- Removed in `<handlers>` and `<modules>` in web.config
- WebDAV intercepts PUT/DELETE, causing 405 errors on REST endpoints

**5. xcopy/robocopy Deployment (No MSDeploy)**
- Manual deployment uses robocopy with `/MIR` flag
- Always snapshot before deploying for rollback

**Migration Impact:**
- Upload config moves to App Service web.config + Azure Blob Storage client
- Connection strings become Azure App Service settings (env vars)
- WebDAV removal can be dropped from transformed configs
- xcopy replaced by CI/CD pipeline (out of scope)

### 2026-04-29T20:58:45.246Z: .gitignore and Binary Tracking Cleanup
**By:** Theo  
**Status:** Accepted

Added a comprehensive .NET Framework 4.6 / Visual Studio 2015-era .gitignore and removed previously committed NuGet package binaries and MSBuild obj artifacts from git tracking.

**Key Rules:**
1. `src/packages/` is never committed — NuGet restore produces it from packages.config
2. `bin/` and `obj/` are never committed — MSBuild output, always reproducible
3. `.vs/`, `*.suo`, `*.user` are never committed — developer-local VS settings

**Team Impact:**
- Fresh clones won't have `src/packages/` — developers must run NuGet restore before first build
- Karl: ensure build instructions note NuGet restore requirement

### 2026-04-29T21:01:36Z: Terraform Infrastructure Structure
**By:** Theo  
**Status:** Proposed

Terraform IaC lives under `infrastructure/` with two independent configurations:
- `infrastructure/legacy/` — Windows Server 2016 VM (IIS + SQL Express)
- `infrastructure/azure/` — PaaS target (App Service + Azure SQL + Blob Storage)

**Key Choices:**
1. azurerm provider ~> 3.80 — stable, well-documented
2. SQL Auth (not AAD) — matches legacy app's SqlClient connection pattern
3. Separate state files — legacy and modern are independent
4. S1 App Service Plan — minimum tier with always-on
5. S0 Azure SQL — cheapest standard tier with SLA
6. Blob container named `attachments` — matches migration story

**Team Impact:**
- Karl: Connection string format for Azure SQL is in Terraform outputs
- Argyle: App Service URL output for API base URL configuration
- McClane: Infrastructure can be provisioned independently before app code is deployed

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
