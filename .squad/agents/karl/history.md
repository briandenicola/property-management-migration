# Karl — History

## Learnings

- Project: Property management app for maintenance requests
- Legacy backend: .NET Framework 4.6, Web API 2, EF6, SQL Server
- File storage: varbinary(max) blobs in SQL Server (legacy anti-pattern to demonstrate)
- Entities: Properties, Tenants, MaintenanceRequests, Attachments (blob table)
- User: Brian
- 2026-04-29T20:40:56.058Z: Implemented full legacy backend solution at `src/PropertyManager.sln` with `PropertyManager.Web`, `PropertyManager.Data`, and `PropertyManager.Core` old-style .NET Framework projects.
- 2026-04-29T20:40:56.058Z: Enforced legacy architecture patterns: Global.asax startup wiring, static `LegacyServiceLocator`, repository + service layers, manual DTO mapping, and packages.config-based NuGet management.
- 2026-04-29T20:40:56.058Z: Implemented complete API surface for properties, tenants, maintenance requests, attachments (multipart upload/download), users, and account endpoints under `src/PropertyManager.Web/Controllers`.
- 2026-04-29T20:40:56.058Z: Implemented EF6 data layer in `src/PropertyManager.Data` with entities, `PropertyManagerContext`, repository implementations, and initial migration `Migrations/20260429204056_InitialCreate.cs`.
- 2026-04-29T20:40:56.058Z: Added SQL schema script at `database/schema.sql` including intentional `Attachments.FileData VARBINARY(MAX)` blob storage anti-pattern for migration story alignment.
- 2026-04-29T20:40:56.058Z: User preference reaffirmed: authentic legacy coding style over modern DI-first design while keeping migration path toward Azure App Service + Azure SQL in config transforms.

### 2026-04-29T20:55:27Z — Scribe: Decisions Archived
- Backend structure decision merged and consolidated in decisions.md
- Orchestration log created at `.squad/orchestration-log/2026-04-29T20-40-56-karl.md`
- Team architecture decisions now unified and available for reference

### 2026-04-29T21:02:29Z — Scribe: Inbox Merged
- Decisions now live in Active Decisions section of decisions.md
- Ready for team alignment on connection string formats and deployment patterns
