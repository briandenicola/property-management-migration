# Property Management Migration

Demonstrates migrating a legacy .NET Framework (4.6.2) property management application from an on-premises IIS/SQL Server stack to Azure App Service and Azure SQL -- end to end, with full infrastructure-as-code and scripted automation.

## What This Is

A **client-facing demo environment** that showcases the complete journey of migrating a line-of-business application to Azure:

1. **Assess** the legacy workload using Azure Migrate
2. **Migrate** the app (build, package, deploy) and database (BACPAC export/import)
3. **Validate** the migrated application is running correctly
4. **Compare** before/after to demonstrate parity

The legacy app is a single-page application (AngularJS 1.x frontend + ASP.NET Web API 2 backend) managing rental properties, tenants, and maintenance requests -- a typical enterprise app circa 2015.

## Repository Structure

```
├── src/                        # .NET Framework 4.6.2 solution
│   ├── PropertyManager.Web/    # Web API 2 + AngularJS SPA
│   ├── PropertyManager.Core/   # Domain models and services
│   └── PropertyManager.Data/   # Entity Framework data layer
├── infrastructure/
│   ├── legacy/                 # Terraform: Windows Server VM + IIS + SQL Express
│   └── azure/                  # Terraform: App Service + Azure SQL
├── scripts/
│   ├── assess.ps1              # Azure Migrate assessment automation
│   ├── migrate.ps1             # Full migration pipeline (build → BACPAC → deploy)
│   ├── validate.ps1            # Post-migration health checks
│   └── compare.ps1             # Side-by-side legacy vs Azure comparison
├── database/                   # SQL schema and seed data
├── docs/                       # Documentation (see below)
└── Taskfile.yaml               # Task runner commands
```

## Quick Start

### Prerequisites

- Azure CLI (`az login` authenticated)
- PowerShell 7+
- Terraform >= 1.5
- Visual Studio 2018+ or standalone MSBuild
- [Task](https://taskfile.dev) CLI

### Provision Infrastructure

```powershell
# Legacy VM (IIS + SQL Express)
cd infrastructure/legacy && terraform init && terraform apply

# Azure target (App Service + Azure SQL)
cd infrastructure/azure && terraform init && terraform apply
```

### Run the Migration

```powershell
# Full pipeline: build → package → BACPAC → deploy → configure → restart
powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1
```

## Documentation

| Document | Description |
|----------|-------------|
| [Demo Guide](docs/demo-guide.md) | 18-minute narrated walkthrough for client presentations |
| [Talking Points](docs/talking-points.md) | Value propositions, objection handling, TCO breakdown |
| [Legacy Architecture](docs/architecture-legacy.md) | Full architecture blueprint of the legacy application |
| [Deployment Guide](docs/DEPLOYMENT.md) | Step-by-step legacy VM deployment instructions |
| [IIS Setup](docs/iis-setup.md) | IIS configuration details (auto-provisioned by Terraform) |

## Migration Scripts

| Script | Purpose |
|--------|---------|
| `scripts/assess.ps1` | Registers an Azure Migrate project and runs a readiness assessment |
| `scripts/migrate.ps1` | End-to-end migration: MSBuild → zip package → BACPAC export/import → App Service deploy → connection string → health check |
| `scripts/validate.ps1` | Verifies the migrated app responds correctly on Azure |
| `scripts/compare.ps1` | Hits both legacy and Azure endpoints to show functional parity |

## Technology Stack

| Layer | Legacy (Before) | Azure (After) |
|-------|-----------------|---------------|
| Compute | Windows Server 2016 VM + IIS 10 | Azure App Service (Windows) |
| Database | SQL Server 2016 Express (local) | Azure SQL Database |
| Auth | Windows/Forms (stripped for demo) | Entra ID (SQL), Managed Identity |
| Infra | Manual / RDP | Terraform IaC |
| Deploy | Web Deploy / xcopy | Zip Deploy via Azure CLI |

## License

Internal demo asset -- not for distribution.
