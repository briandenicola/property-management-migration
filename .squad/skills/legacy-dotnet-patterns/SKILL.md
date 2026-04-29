---
name: "legacy-dotnet-patterns"
description: "Patterns for building authentic .NET Framework 4.6 legacy applications (~2015 era)"
domain: "architecture"
confidence: "high"
source: "manual"
---

## Context
When building legacy .NET Framework applications that need to feel authentically era-appropriate (2013–2016). Used as the "before" state in modernization/migration demos.

## Patterns
- Web API 2 with attribute routing (`[RoutePrefix]`, `[Route]`)
- Entity Framework 6 Code First with `DbContext` directly in controllers
- Unity IoC container registered in `App_Start/UnityConfig.cs` (but inconsistently used)
- `Global.asax.cs` for `Application_Start` with `GlobalConfiguration.Configure()`
- `web.config` for connection strings, app settings, IIS config — no secrets management
- Cookie-based auth via ASP.NET Identity 2.x
- `MultipartMemoryStreamProvider` for file uploads
- AngularJS frontend colocated in `/app` folder within the Web API project
- Bower for frontend packages, Grunt/Gulp for build (no webpack)
- IIFE pattern wrapping all Angular modules
- `$http` service for API calls, jQuery `$.ajax` for file uploads (mixed pattern)
- Bootstrap 3 panels, glyphicons, dl-horizontal for layout

## Examples
- Controller: `new PropertyProDbContext()` in constructor (no DI for some controllers)
- Sync DB calls: `_context.SaveChanges()` instead of async
- File storage: `byte[] → varbinary(MAX)` in SQL Server
- Frontend routing: UI-Router states, not ngRoute
- Component pattern: `.component()` API (AngularJS 1.5+) with `controllerAs` syntax

## Anti-Patterns
- Do NOT use .NET Core / .NET 5+ patterns
- Do NOT use ES modules or TypeScript
- Do NOT use Angular CLI or webpack
- Do NOT use repository pattern (keep it messy and coupled)
- Do NOT use `ILogger` or structured logging — use `Trace` or nothing
- Do NOT add health check endpoints
- Do NOT use Docker or containerization
