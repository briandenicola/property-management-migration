# Theo — History

## Learnings

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
