# Legacy Infrastructure — Windows Server 2016 VM

This Terraform configuration provisions a Windows Server 2016 Datacenter VM on Azure,
representing the "before" state of the PropertyPro application's production environment.

## What It Creates

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all legacy resources |
| Virtual Network + Subnet | Isolated network for the VM |
| Public IP (Static) | External access for HTTP/RDP |
| NSG | Firewall rules: HTTP (80), HTTPS (443), RDP (3389 from allowed IP only) |
| Windows Server 2016 VM | IIS + SQL Server Express host |
| Data Disk (64 GB) | Dedicated SQL Server data file storage |
| Custom Script Extension | Automated IIS + SQL Server setup |

## Prerequisites

- [Terraform >= 1.5](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) authenticated (`az login`)
- An Azure subscription

## Usage

```bash
# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (especially admin_password, sql_sa_password, allowed_rdp_ip)

# 2. Initialize Terraform
terraform init

# 3. Review the plan
terraform plan

# 4. Apply
terraform apply

# 5. Connect via RDP
# Use the output rdp_connection_string value
terraform output rdp_connection_string
```

## Post-Provisioning

The Custom Script Extension runs `scripts/setup-legacy-server.ps1` which:
1. Initializes and formats the data disk (F: drive)
2. Installs IIS with ASP.NET 4.6 features
3. Downloads and installs SQL Server 2016 Express
4. Creates the `PropertyManager` database on the data disk
5. Configures the IIS site pointing to `C:\inetpub\PropertyPro`

## Destroying Resources

```bash
terraform destroy
```

## Security Notes

- RDP is restricted to the IP specified in `allowed_rdp_ip`
- Never commit `terraform.tfvars` with real credentials
- The VM uses a local admin account — not domain-joined
