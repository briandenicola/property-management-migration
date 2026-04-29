# Squad Team

> property-management-migration

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| McClane | Lead | .squad/agents/mcclane/charter.md | 🏗️ Lead |
| Argyle | Frontend Dev | .squad/agents/argyle/charter.md | ⚛️ Frontend |
| Karl | Backend Dev | .squad/agents/karl/charter.md | 🔧 Backend |
| Theo | Cloud/DevOps | .squad/agents/theo/charter.md | ⚙️ DevOps |
| Scribe | Scribe | .squad/agents/scribe/charter.md | 📋 Scribe |
| Ralph | Work Monitor | .squad/agents/ralph/charter.md | 🔄 Monitor |

## Project Context

- **Project:** property-management-migration
- **User:** Brian
- **Created:** 2026-04-29
- **Stack (Legacy):** AngularJS, .NET Framework 4.6, SQL Server, IIS on Windows
- **Stack (Target):** Angular (modern), .NET 8+, Azure App Services, Azure SQL
- **Domain:** Property management — maintenance requests with image/document uploads
- **Storage:** Documents/images stored as blobs in SQL Server (legacy), migration to Azure Blob Storage (target)
- **Goal:** Build the legacy app, then demonstrate AI-assisted migration to Azure
