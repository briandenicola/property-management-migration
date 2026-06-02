# Property Management Migration

Demonstrates migrating a legacy .NET Framework (4.6.2) property management application from on-premises IIS with Windows/Domain Authentication to Azure App Service with Entra ID Easy Auth — including full infrastructure-as-code, authentication migration, and scripted automation.

## What This Is

A **demo environment** showcasing the complete journey of migrating a line-of-business application to Azure, with emphasis on **authentication modernization**:

| Aspect | Legacy | Azure |
|--------|--------|-------|
| Compute | Windows Server 2016 + IIS 10 | Azure App Service (Windows) |
| Database | SQL Server Express (local) | Azure SQL Database |
| Auth | Windows/Domain Authentication (AD groups → roles) | Entra ID + Easy Auth (App Roles) |
| Identity | Active Directory domain join | Microsoft Entra ID |
| Infra | Terraform-provisioned VM | Terraform-provisioned PaaS |
| Deploy | Manual via Bastion/RDP | `task azure:deploy` (zip deploy) |

The app is a single-page application (AngularJS 1.x frontend + ASP.NET Web API 2 backend) managing rental properties, tenants, and maintenance requests — a typical enterprise app circa 2015.

## Repository Structure

```
├── src/
│   ├── Legacy/                     # Full .NET 4.6.2 solution — Windows Auth on IIS
│   │   ├── PropertyManager.sln
│   │   ├── PropertyManager.Web/    # Web API 2 + AngularJS SPA + Windows Auth
│   │   ├── PropertyManager.Core/   # Domain services and interfaces
│   │   └── PropertyManager.Data/   # Entity Framework 6 data layer
│   └── Azure/                      # Full .NET 4.6.2 solution — Easy Auth on App Service
│       ├── PropertyManager.sln
│       ├── PropertyManager.Web/    # Web API 2 + AngularJS SPA + Easy Auth
│       ├── PropertyManager.Core/   # Domain services and interfaces
│       └── PropertyManager.Data/   # Entity Framework 6 data layer
├── infrastructure/
│   ├── legacy/                     # Terraform: DC + IIS VM + Client VM
│   └── azure/                      # Terraform: App Service + Azure SQL + Entra config
├── scripts/                        # Migration automation scripts
├── database/                       # SQL schema and seed data
├── docs/                           # Documentation
└── Taskfile.yaml                   # Task runner commands
```

## Key Differences: Legacy vs Azure Source

Both `src/Legacy/` and `src/Azure/` are complete, independently compilable projects. The key changes in the Azure version:

- **`Controllers/AccountController.cs`** — reads `X-MS-CLIENT-PRINCIPAL` header instead of `WindowsIdentity`
- **`Filters/EasyAuthRoleAuthorizeAttribute.cs`** — replaces `WindowsRoleAuthorizeAttribute`; reads app roles from Easy Auth claims
- **`Modules/EasyAuthModule.cs`** — HTTP module that hydrates `HttpContext.User` from Easy Auth headers so `[Authorize]` works
- **`web.config`** — no Windows Auth sections; Easy Auth handles authentication at the platform level
- All controllers use `[EasyAuthRoleAuthorize]` instead of `[WindowsRoleAuthorize]`

## Quick Start

### Prerequisites

- Azure CLI (`az login` authenticated)
- PowerShell 7+ (`pwsh`)
- Terraform >= 1.5
- Visual Studio 2018+ or standalone MSBuild
- [Task](https://taskfile.dev) CLI

### Build

```powershell
# Build the Azure version
task build -- azure

# Build the Legacy version
task build -- legacy
```

### Provision Infrastructure

```powershell
# Legacy environment (Domain Controller + IIS VM + Client VM)
task legacy:up

# Azure environment (App Service + Azure SQL + Entra config)
task azure:up
```

### Deploy to Azure

```powershell
task azure:deploy
```

### Entra ID App Registration Setup

Before deploying Azure infrastructure, create an App Registration manually:

1. **Azure Portal** → App registrations → New registration (single tenant)
2. **App roles** → Create `Admin` and `User` roles
3. **Authentication** → Enable **ID tokens** (implicit grant) ⚠️ Required
4. Copy the **Application (client) ID** to `infrastructure/azure/.env`:
   ```
   ENTRA_APP_CLIENT_ID=<your-client-id>
   ```

See [Easy Auth Migration Guide](docs/easy-auth-migration.md) for full details.

## Documentation

| Document | Description |
|----------|-------------|
| [Easy Auth Migration](docs/easy-auth-migration.md) | Side-by-side comparison of Windows Auth → Easy Auth code changes |
| [Windows Authentication](docs/windows-authentication.md) | How the legacy Windows/Domain Auth works |
| [Demo Guide](docs/demo-guide.md) | Narrated walkthrough for presentations |
| [Legacy Architecture](docs/architecture-legacy.md) | Architecture blueprint of the legacy application |
| [Deployment Guide](docs/DEPLOYMENT.md) | Legacy VM deployment instructions |
| [IIS Setup](docs/iis-setup.md) | IIS configuration (auto-provisioned by Terraform) |

## Task Commands

```powershell
task --list              # Show all available tasks
task build -- azure      # Build the Azure solution
task build -- legacy     # Build the Legacy solution
task azure:up            # Provision Azure infrastructure
task azure:deploy        # Build + deploy to App Service
task azure:plan          # Show Terraform plan
task azure:down          # Tear down Azure resources
task legacy:up           # Provision legacy infrastructure
task legacy:down         # Tear down legacy resources
```

## License

Internal demo asset — not for distribution.
