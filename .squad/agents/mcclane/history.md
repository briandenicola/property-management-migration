# McClane — History

## Learnings

- Project: Property management app for maintenance requests with image/document uploads
- Legacy: AngularJS 1.x, .NET Framework 4.6 (Web API 2), SQL Server (blobs in DB), IIS/Windows
- Target: Modern Angular, .NET 8+, Azure App Services, Azure SQL, Azure Blob Storage
- Goal: Build legacy first, then demonstrate AI-assisted migration
- User: Brian

### Architecture Decisions (2026-04-29)
- Legacy app name: **PropertyPro**
- Solution structure: single .sln with `PropertyPro.Web` (API + SPA host) and `PropertyPro.Tests`
- Frontend lives inside Web project at `/app` (era-appropriate — no separate SPA build pipeline)
- AngularJS 1.5 component pattern with UI-Router, Bower+Grunt tooling
- EF6 Code First with migrations, DbContext directly in controllers (intentional anti-pattern)
- File uploads use `MultipartMemoryStreamProvider` → `varbinary(MAX)` in SQL (key migration driver)
- Unity IoC container registered in App_Start (minimal usage — some controllers still `new` up context)
- Cookie-based auth via ASP.NET Identity 2.x
- Status workflow: Open → InProgress → Completed → Closed
- Priority enum: Low, Medium, High, Emergency
- API prefix: `/api/` with attribute routing
# McClane — History

## Learnings

- Project: Property management app for maintenance requests with image/document uploads
- Legacy: AngularJS 1.x, .NET Framework 4.6 (Web API 2), SQL Server (blobs in DB), IIS/Windows
- Target: Modern Angular, .NET 8+, Azure App Services, Azure SQL, Azure Blob Storage
- Goal: Build legacy first, then demonstrate AI-assisted migration
- User: Brian

### Architecture Decisions (2026-04-29)
- Legacy app name: **PropertyPro**
- Solution structure: single .sln with `PropertyPro.Web` (API + SPA host) and `PropertyPro.Tests`
- Frontend lives inside Web project at `/app` (era-appropriate — no separate SPA build pipeline)
- AngularJS 1.5 component pattern with UI-Router, Bower+Grunt tooling
- EF6 Code First with migrations, DbContext directly in controllers (intentional anti-pattern)
- File uploads use `MultipartMemoryStreamProvider` → `varbinary(MAX)` in SQL (key migration driver)
- Unity IoC container registered in App_Start (minimal usage — some controllers still `new` up context)
- Cookie-based auth via ASP.NET Identity 2.x
- Status workflow: Open → InProgress → Completed → Closed
- Priority enum: Low, Medium, High, Emergency
- API prefix: `/api/` with attribute routing
- Key doc: `docs/architecture-legacy.md`

### 2026-04-29T20:55:27Z — Scribe: Decisions Archived
- All 6 inbox decision files merged into decisions.md
- Architecture blueprint decision documented in consolidated decisions.md
- Orchestration log created at `.squad/orchestration-log/2026-04-29T20-40-56-mcclane.md`
- Team decisions now consolidated and ready for git commit

### 2026-04-29T21:02:29Z — Scribe: Inbox Merged
- Terraform infrastructure decisions now in Active Decisions
- Legacy VM and PaaS target configurations available for reference
- Infrastructure provisioning can be initiated independently before app deployment
