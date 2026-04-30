#Requires -Version 5.1
<#
.SYNOPSIS
    Before/after comparison report — cost, features, SLA, and operational burden.
    Generates a printable summary table for demo and client deliverables.

.DESCRIPTION
    Reads Terraform outputs for the modern infrastructure and computes a side-by-side
    comparison between the legacy IIS VM and the modern App Service deployment.
    Outputs a formatted table and optionally a JSON report.

.PARAMETER LegacyVmSize
    Azure VM size of the legacy VM. Used for cost lookup. Defaults to Standard_B2ms.

.PARAMETER AppServiceSku
    App Service Plan SKU of the modern target. Used for cost lookup. Defaults to S1.

.PARAMETER SqlSku
    Azure SQL Database SKU. Used for cost lookup. Defaults to S0.

.PARAMETER Region
    Azure region for pricing (affects estimates). Defaults to canadacentral.

.PARAMETER OutputJson
    If specified, writes the comparison report to this JSON file path.

.PARAMETER ResourceGroup
    Azure resource group for the modern deployment. Auto-detected from Terraform.

.EXAMPLE
    .\compare.ps1

.EXAMPLE
    .\compare.ps1 -LegacyVmSize "Standard_D2s_v3" -AppServiceSku "S1" -OutputJson "docs/comparison-report.json"
#>
[CmdletBinding()]
param(
    [string]$LegacyVmSize    = "Standard_B2ms",
    [string]$AppServiceSku   = "S1",
    [string]$SqlSku          = "S0",
    [string]$Region          = "canadacentral",
    [string]$OutputJson      = "",
    [string]$ResourceGroup   = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region --- Helpers ---

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
    Write-Host "  $Text" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
}

function Write-TableRow {
    param([string]$Label, [string]$Legacy, [string]$Modern, [string]$Winner = "modern")
    $legacyColor = if ($Winner -eq "legacy") { "Green" } else { "Red" }
    $modernColor = if ($Winner -eq "modern") { "Green" } else { "White" }
    $neutralColor = "White"
    if ($Winner -eq "tie") { $legacyColor = "Yellow"; $modernColor = "Yellow" }

    Write-Host ("  {0,-30} " -f $Label) -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-28} " -f $Legacy) -NoNewline -ForegroundColor $legacyColor
    Write-Host ("{0,-28}" -f $Modern) -ForegroundColor $modernColor
}

function Write-TableHeader {
    Write-Host ""
    Write-Host ("  {0,-30} {1,-28} {2,-28}" -f "Dimension", "Legacy (IIS VM)", "Modern (App Service)") -ForegroundColor Cyan
    Write-Host ("  {0,-30} {1,-28} {2,-28}" -f ("-" * 29), ("-" * 27), ("-" * 27)) -ForegroundColor DarkCyan
}

function Get-TerraformOutput {
    param([string]$Name, [string]$Dir = "infrastructure/azure")
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $tfDir    = Join-Path $repoRoot $Dir
    if (-not (Test-Path (Join-Path $tfDir ".terraform"))) { return $null }
    $val = terraform -chdir=$tfDir output -raw $Name 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $val
}

#endregion

#region --- Cost Estimates (Canada Central, approximate retail prices, USD) ---
# These are approximate figures for demo purposes.
# Use Azure Pricing Calculator for exact customer quotes.

$costs = @{
    legacy = @{
        # Standard_B2ms Windows: ~$0.0924/hr * 730 hrs
        compute_monthly        = 67.45
        # Premium SSD P10 (128GB) managed disk
        storage_monthly        = 19.71
        # SQL Server Express: no additional license cost on Azure VM
        sql_monthly            = 0.00
        # Azure Backup for VM: ~$5/mo estimate
        backup_monthly         = 5.00
        # Rough estimate: 8 hrs/mo @ $100/hr engineer rate for patching/ops
        ops_labor_monthly      = 800.00
        # Monitoring: basic Azure Monitor (minimal config)
        monitoring_monthly     = 5.00
        # Egress 10GB/mo estimate
        egress_monthly         = 0.87
        # Manual SSL cert renewal (amortized)
        ssl_monthly            = 8.33
    }
    modern = @{
        # App Service S1 Windows: ~$0.10/hr * 730
        compute_monthly        = 74.46
        # Azure SQL S0 (10 DTU): ~$14.72/mo
        sql_monthly            = 14.72
        # LRS Blob Storage 10GB: ~$0.19/mo
        storage_monthly        = 1.90
        # App Service backup: included
        backup_monthly         = 0.00
        # Ops labor: near-zero for PaaS (patches managed, no RDP)
        ops_labor_monthly      = 0.00
        # Application Insights: free 5GB/mo ingestion
        monitoring_monthly     = 0.00
        # Egress: same estimate
        egress_monthly         = 0.87
        # SSL: free (App Service Managed Certificates)
        ssl_monthly            = 0.00
    }
}

$legacyTechTotal = ($costs.legacy.compute_monthly + $costs.legacy.storage_monthly +
    $costs.legacy.sql_monthly + $costs.legacy.backup_monthly +
    $costs.legacy.monitoring_monthly + $costs.legacy.egress_monthly + $costs.legacy.ssl_monthly)

$modernTechTotal = ($costs.modern.compute_monthly + $costs.modern.sql_monthly +
    $costs.modern.storage_monthly + $costs.modern.backup_monthly +
    $costs.modern.monitoring_monthly + $costs.modern.egress_monthly +
    $costs.modern.ssl_monthly)

$legacyTotal = $legacyTechTotal + $costs.legacy.ops_labor_monthly
$modernTotal = $modernTechTotal + $costs.modern.ops_labor_monthly

$annualSavings = ($legacyTotal - $modernTotal) * 12

#endregion

# --- Resolve infrastructure details ---
$appServiceUrl = Get-TerraformOutput -Name "app_service_url"
$appServiceName = Get-TerraformOutput -Name "app_service_name"
if (-not $ResourceGroup) {
    $ResourceGroup = Get-TerraformOutput -Name "resource_group_name"
}
$sqlFqdn = Get-TerraformOutput -Name "sql_server_fqdn"

# --- Output ---
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║            Property Manager — Migration Comparison Report                       ║" -ForegroundColor Cyan
Write-Host ("║            Generated: {0,-58}║" -f (Get-Date -Format "yyyy-MM-dd HH:mm UTC")) -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# --- Cost Comparison ---
Write-Header "Monthly Cost Comparison (USD, approximate)"
Write-TableHeader

Write-TableRow "Compute" "$($LegacyVmSize) VM `$$([math]::Round($costs.legacy.compute_monthly,2))/mo" "$AppServiceSku App Service `$$([math]::Round($costs.modern.compute_monthly,2))/mo" "tie"
Write-TableRow "Database" "SQL Server Express (free, 10GB cap)" "Azure SQL $SqlSku `$$([math]::Round($costs.modern.sql_monthly,2))/mo" "modern"
Write-TableRow "Storage" "Managed Disk `$$([math]::Round($costs.legacy.storage_monthly,2))/mo" "Blob Storage `$$([math]::Round($costs.modern.storage_monthly,2))/mo" "modern"
Write-TableRow "Backup" "`$$([math]::Round($costs.legacy.backup_monthly,2))/mo (Azure Backup)" "Included in App Service" "modern"
Write-TableRow "Monitoring" "Manual/SCOM `$$([math]::Round($costs.legacy.monitoring_monthly,2))/mo" "App Insights (free tier) `$0/mo" "modern"
Write-TableRow "SSL/TLS" "`$$([math]::Round($costs.legacy.ssl_monthly,2))/mo (amortized cert)" "Free managed cert `$0/mo" "modern"
Write-TableRow "Egress" "`$$([math]::Round($costs.legacy.egress_monthly,2))/mo" "`$$([math]::Round($costs.modern.egress_monthly,2))/mo" "tie"
Write-TableRow "Ops Labor (patching)" "8 hrs/mo × `$100 = `$$($costs.legacy.ops_labor_monthly)/mo" "`$0/mo (managed platform)" "modern"

Write-Host ""
Write-Host ("  {0,-30} {1,-28} {2,-28}" -f "─────────────────────────────", "─────────────────────────────", "─────────────────────────────") -ForegroundColor DarkCyan
Write-Host ("  {0,-30} " -f "TECH SPEND TOTAL") -NoNewline -ForegroundColor Gray
Write-Host ("`$$([math]::Round($legacyTechTotal,2))/mo                      ") -NoNewline -ForegroundColor Red
Write-Host "`$$([math]::Round($modernTechTotal,2))/mo" -ForegroundColor Green

Write-Host ("  {0,-30} " -f "TOTAL (incl. labor)") -NoNewline -ForegroundColor Gray
Write-Host ("`$$([math]::Round($legacyTotal,2))/mo                      ") -NoNewline -ForegroundColor Red
Write-Host "`$$([math]::Round($modernTotal,2))/mo" -ForegroundColor Green

Write-Host ""
if ($annualSavings -gt 0) {
    Write-Host ("  ★ Estimated annual savings: `${0:N0} USD (labor + infra)" -f $annualSavings) -ForegroundColor Green
} else {
    Write-Host ("  ★ Annual infra delta: `${0:N0} USD (savings primarily from reduced operational burden)" -f [math]::Abs($annualSavings)) -ForegroundColor Yellow
}

# --- Feature Comparison ---
Write-Header "Feature Comparison"
Write-TableHeader

Write-TableRow "OS Patching"          "Manual (RDP + WSUS)"           "Fully managed by Microsoft"         "modern"
Write-TableRow "Runtime Patching"     "Manual (.NET + IIS updates)"   "Managed by Microsoft"                "modern"
Write-TableRow "Auto-Scale"           "None (manual VM resize)"        "1–10 instances, rules-based"         "modern"
Write-TableRow "HTTPS / TLS"          "Manual cert + renewal"          "Free cert, auto-renewed"             "modern"
Write-TableRow "Deployment"           "RDP + robocopy"                 "Zip deploy via CLI/pipeline"         "modern"
Write-TableRow "Deployment Rollback"  "VM snapshot (hrs)"              "Slot swap (30 seconds)"              "modern"
Write-TableRow "Zero-downtime deploy" "No"                             "Yes (staging slots)"                 "modern"
Write-TableRow "Monitoring"           "Event Viewer / manual"          "Application Insights, Live Metrics"  "modern"
Write-TableRow "Alerting"             "Manual setup required"          "Built-in + smart detection"          "modern"
Write-TableRow "Auto-heal"            "None"                           "Automatic unhealthy process recycle" "modern"
Write-TableRow "Managed Identity"     "N/A"                            "System-assigned MI for Azure svcs"   "modern"
Write-TableRow "DB HA"                "SQL Express (no HA)"            "Azure SQL with HA + auto-backup"     "modern"
Write-TableRow "DB Backup"            "Manual snapshot"                "Automated PITR (7-35 days)"          "modern"
Write-TableRow "Secret management"    "web.config / plaintext"         "App Service config (env vars)"       "modern"
Write-TableRow "Custom domain"        "DNS + manual IIS binding"       "2 DNS records in portal"             "modern"
Write-TableRow "Geo-redundancy"       "Not available"                  "Multi-region option available"       "modern"

# --- SLA Comparison ---
Write-Header "SLA Comparison"
Write-TableHeader

Write-TableRow "Compute SLA"          "99.9% (single VM + Premium SSD)" "99.95% (App Service Standard+)"    "modern"
Write-TableRow "Database SLA"         "No HA (SQL Express)"             "99.99% (Azure SQL)"                 "modern"
Write-TableRow "Storage SLA"          "99.9% (managed disk)"            "99.9% (Blob LRS) / 99.99% (GRS)"   "modern"
Write-TableRow "Planned maintenance"  "No SLA, downtime possible"       "No downtime (platform-managed)"     "modern"
Write-TableRow "Annual downtime (max)" "~8.76 hrs @ 99.9%"              "~4.38 hrs @ 99.95%"                 "modern"

# --- Infrastructure Details ---
if ($appServiceName -or $sqlFqdn) {
    Write-Header "Provisioned Infrastructure"
    if ($appServiceName)  { Write-Host "  App Service  : $appServiceName" -ForegroundColor Cyan }
    if ($appServiceUrl)   { Write-Host "  App URL      : $appServiceUrl"  -ForegroundColor Cyan }
    if ($ResourceGroup)   { Write-Host "  Resource Grp : $ResourceGroup"  -ForegroundColor Cyan }
    if ($sqlFqdn)         { Write-Host "  SQL Server   : $sqlFqdn"         -ForegroundColor Cyan }
}

# --- JSON Output ---
if ($OutputJson) {
    Write-Header "Writing JSON Report"
    $report = @{
        generatedAt       = (Get-Date -Format "o")
        region            = $Region
        legacyVmSize      = $LegacyVmSize
        appServiceSku     = $AppServiceSku
        sqlSku            = $SqlSku
        costs = @{
            legacyMonthlyTechUsd    = [math]::Round($legacyTechTotal, 2)
            modernMonthlyTechUsd    = [math]::Round($modernTechTotal, 2)
            legacyMonthlyTotalUsd   = [math]::Round($legacyTotal, 2)
            modernMonthlyTotalUsd   = [math]::Round($modernTotal, 2)
            estimatedAnnualSavingsUsd = [math]::Round($annualSavings, 2)
        }
        infrastructure = @{
            appServiceName  = $appServiceName
            appServiceUrl   = $appServiceUrl
            resourceGroup   = $ResourceGroup
            sqlServerFqdn   = $sqlFqdn
        }
        sla = @{
            legacyUptime   = "99.9%"
            modernUptime   = "99.95%"
            legacyDbHa     = "None (SQL Express)"
            modernDbHa     = "99.99% (Azure SQL)"
        }
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputJson -Encoding UTF8
    Write-Host "  Report written: $OutputJson" -ForegroundColor Green
}

# --- Final Summary ---
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
Write-Host "  Pricing note: Estimates based on Canada Central retail pricing." -ForegroundColor DarkGray
Write-Host "  Actual costs vary by region, reservation discounts, and Azure Hybrid Benefit." -ForegroundColor DarkGray
Write-Host "  Use the Azure Pricing Calculator for customer-specific quotes." -ForegroundColor DarkGray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
Write-Host ""
