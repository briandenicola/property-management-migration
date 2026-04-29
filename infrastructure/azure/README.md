# Modern PaaS Infrastructure — Azure App Service + SQL + Blob

This Terraform configuration provisions the migration target for the PropertyPro application:
a fully managed Azure PaaS environment replacing the legacy IIS/SQL Server VM.

## What It Creates

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all modern resources |
| App Service Plan (S1, Windows) | Compute for the web application |
| Windows Web App (.NET 4.6) | Hosts the migrated PropertyPro application |
| Azure SQL Server + Database | Managed SQL replacing SQL Server Express |
| Storage Account + Container | Blob storage for migrated file attachments |
| Application Insights + Log Analytics | Monitoring and diagnostics |
| SQL Firewall Rules | Access control for Azure services and dev IPs |

## Prerequisites

- [Terraform >= 1.5](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) authenticated (`az login`)
- An Azure subscription

## Usage

```bash
# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — especially sql_admin_password and app_name_prefix (must be globally unique)

# 2. Initialize Terraform
terraform init

# 3. Review the plan
terraform plan

# 4. Apply
terraform apply

# 5. Get outputs
terraform output app_service_url
terraform output -raw sql_connection_string  # sensitive
terraform output -raw storage_connection_string  # sensitive
```

## Deployment

After provisioning, deploy the application:

```bash
# Using Azure CLI
az webapp deploy --resource-group pm-modern-rg \
  --name pm-modern-app \
  --src-path ./publish.zip \
  --type zip
```

## Architecture Notes

- **Connection strings** are injected into the App Service as environment variables
- **Blob storage** replaces the legacy `varbinary(MAX)` attachment pattern
- **Application Insights** provides monitoring not available in the legacy environment
- **SQL Firewall** allows Azure services by default; add developer IPs via `allowed_ip_addresses`
- The App Service uses a **System-Assigned Managed Identity** (ready for Key Vault integration)

## Destroying Resources

```bash
terraform destroy
```

## Security Notes

- SQL admin credentials are marked `sensitive` in outputs
- Storage connection string is marked `sensitive`
- Never commit `terraform.tfvars` with real credentials
- Consider Azure Key Vault for production secret management
