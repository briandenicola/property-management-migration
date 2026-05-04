#Requires -Version 5.1
<#
.SYNOPSIS
    Fallback migration script -- build, package, and deploy the Property Manager app
    to Azure App Service via zip deploy.

.DESCRIPTION
    This script is the CI/CD-equivalent deployment pipeline for the demo. It:
      1. Restores NuGet packages
      2. Builds the solution in Release configuration (MSBuild)
      3. Publishes the web project to a temp directory
      4. Creates a deployment zip package
      5. Exports the legacy SQL Express database to BACPAC
      6. Imports the BACPAC into Azure SQL (using Entra ID access token)
      7. Deploys via 'az webapp deploy' (zip deploy)
      8. Updates App Service connection strings from Terraform outputs
      9. Verifies the deployment is healthy

    Use -SkipBuild if a prior build artifact exists in .\publish\.
    Use -DryRun to validate the build succeeds without deploying.
    Use -ConnectionStringOnly to only push the connection string (skips build + deploy).

.PARAMETER ResourceGroup
    Target App Service resource group. Auto-detected from Terraform outputs if omitted.

.PARAMETER AppServiceName
    Target App Service name. Auto-detected from Terraform outputs if omitted.

.PARAMETER SubscriptionId
    Azure subscription ID. Defaults to the demo subscription.

.PARAMETER MsBuildPath
    Path to MSBuild.exe. Defaults to VS 2022 Enterprise location.

.PARAMETER SolutionFile
    Path to the solution file. Defaults to repo-relative path.

.PARAMETER WebProjectFile
    Path to the web project file. Defaults to repo-relative path.

.PARAMETER PublishDir
    Directory to publish files to before zipping. Defaults to .\publish\.

.PARAMETER SkipBuild
    Skip the build step -- use existing artifacts in PublishDir.

.PARAMETER DryRun
    Build and package but do not deploy to Azure.

.PARAMETER ConnectionStringOnly
    Only update the connection string on App Service -- skip build and zip deploy.

.EXAMPLE
    .\migrate.ps1

.EXAMPLE
    .\migrate.ps1 -DryRun

.EXAMPLE
    .\migrate.ps1 -SkipBuild -ResourceGroup "myapp-rg" -AppServiceName "myapp"

.EXAMPLE
    .\migrate.ps1 -ConnectionStringOnly
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup    = "",
    [string]$AppServiceName   = "",
    [string]$SubscriptionId   = "ccfc5dda-43af-4b5e-8cc2-1dda18f2382e",
    [string]$MsBuildPath      = "C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    [string]$SolutionFile     = "",
    [string]$WebProjectFile   = "",
    [string]$PublishDir       = "",
    [switch]$SkipBuild,
    [switch]$DryRun,
    [switch]$ConnectionStringOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region --- Helpers ---

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkMagenta
    Write-Host "  $Text" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkMagenta
}

function Write-Step {
    param([string]$Text)
    Write-Host "  ▶ $Text" -ForegroundColor White
}

function Write-Success {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  [!!] $Text" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Text)
    Write-Host "  [XX] $Text" -ForegroundColor Red
}

function Get-RepoRoot {
    return Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

function Get-TerraformOutput {
    param([string]$Name, [string]$Dir = "infrastructure/azure")
    $repoRoot = Get-RepoRoot
    $tfDir    = Join-Path $repoRoot $Dir
    if (-not (Test-Path (Join-Path $tfDir ".terraform"))) { return $null }
    try {
        Push-Location $tfDir
        $val = terraform output -raw $Name 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return $val
    } finally {
        Pop-Location
    }
}

function Invoke-AzCli {
    param([string[]]$CliArgs)
    $result = az @CliArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "az $($CliArgs -join ' ') failed:`n$result" }
    return $result
}

function Find-SqlPackage {
    # Check if already on PATH
    $onPath = Get-Command "SqlPackage.exe" -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    # Check common install locations (newest version first)
    $searchPaths = @(
        "C:\Program Files\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe",
        "C:\Program Files (x86)\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe"
    )
    foreach ($pattern in $searchPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    # Check dotnet global tools
    $dotnetToolPath = Join-Path $env:USERPROFILE ".dotnet\tools\SqlPackage.exe"
    if (Test-Path $dotnetToolPath) { return $dotnetToolPath }

    return $null
}

#endregion

$repoRoot = Get-RepoRoot

# Default paths
if (-not $SolutionFile)  { $SolutionFile  = Join-Path $repoRoot "src\PropertyManager.sln" }
if (-not $WebProjectFile){ $WebProjectFile = Join-Path $repoRoot "src\PropertyManager.Web\PropertyManager.Web.csproj" }
if (-not $PublishDir)    { $PublishDir    = Join-Path $repoRoot "publish" }

$ZipPath = Join-Path $repoRoot "publish\PropertyManager.zip"

Write-Header "Property Manager -- Azure App Service Migration"
if ($DryRun)             { Write-Warn "DRY RUN -- build only, no deployment." }
if ($SkipBuild)          { Write-Warn "SKIP BUILD -- using existing artifacts in $PublishDir" }
if ($ConnectionStringOnly){ Write-Warn "CONNECTION STRING ONLY -- skipping build and deploy." }

# --- Step 1: Resolve Azure targets ---
Write-Header "Step 1 -- Resolve Azure Target"
Write-Step "Setting subscription $SubscriptionId..."
Invoke-AzCli @("account", "set", "--subscription", $SubscriptionId)
Write-Success "Subscription set."

if (-not $ResourceGroup) {
    Write-Step "Detecting resource group from Terraform..."
    $ResourceGroup = Get-TerraformOutput -Name "resource_group_name"
    if ($ResourceGroup) { Write-Success "Resource group: $ResourceGroup" }
    else {
        Write-Fail "Cannot detect resource group. Run 'task azure:up' or provide -ResourceGroup."
        exit 1
    }
}

if (-not $AppServiceName) {
    Write-Step "Detecting App Service name from Terraform..."
    $AppServiceName = Get-TerraformOutput -Name "app_service_name"
    if ($AppServiceName) { Write-Success "App Service: $AppServiceName" }
    else {
        Write-Fail "Cannot detect App Service name. Provide -AppServiceName."
        exit 1
    }
}

$AppServiceUrl = Get-TerraformOutput -Name "app_service_url"
if (-not $AppServiceUrl) {
    $AppServiceUrl = "https://$AppServiceName.azurewebsites.net"
}
Write-Success "Target URL: $AppServiceUrl"

# --- Connection string only mode ---
if ($ConnectionStringOnly) {
    Write-Header "Updating Connection String"
    $connStr = Get-TerraformOutput -Name "sql_connection_string"
    if (-not $connStr) {
        Write-Fail "Could not read sql_connection_string from Terraform. Ensure 'task azure:up' has been run."
        exit 1
    }
    Write-Step "Setting PropertyManager connection string on App Service..."
    Invoke-AzCli @(
        "webapp", "config", "connection-string", "set",
        "--resource-group", $ResourceGroup,
        "--name", $AppServiceName,
        "--settings", "PropertyManager=$connStr",
        "--connection-string-type", "SQLAzure",
        "--output", "none"
    )
    Write-Success "Connection string updated."
    Write-Success "Done. App Service: $AppServiceUrl"
    exit 0
}

# --- Step 2: Build ---
if (-not $SkipBuild) {
    Write-Header "Step 2 -- Build (MSBuild)"

    if (-not (Test-Path $MsBuildPath)) {
        Write-Fail "MSBuild not found at: $MsBuildPath"
        Write-Warn "Install Visual Studio 2022 Enterprise or adjust -MsBuildPath"
        exit 1
    }
    Write-Success "MSBuild found: $MsBuildPath"

    if (-not (Test-Path $SolutionFile)) {
        Write-Fail "Solution not found: $SolutionFile"
        exit 1
    }

    # Clean publish dir
    Write-Step "Cleaning publish directory..."
    if (Test-Path $PublishDir) { Remove-Item -Recurse -Force $PublishDir }
    New-Item -ItemType Directory -Path $PublishDir -Force | Out-Null
    Write-Success "Publish dir clean: $PublishDir"

    # NuGet restore
    Write-Step "Restoring NuGet packages..."
    $restoreArgs = @(
        $SolutionFile,
        "/t:Restore",
        "/p:RestorePackagesConfig=true",
        "/verbosity:minimal",
        "/nologo"
    )
    & $MsBuildPath @restoreArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "NuGet restore failed (exit code $LASTEXITCODE)."
        exit 1
    }
    Write-Success "NuGet restore complete."

    # Compile solution
    Write-Step "Compiling solution (Release)..."
    $buildArgs = @(
        $SolutionFile,
        "/t:Build",
        "/p:Configuration=Release",
        "/verbosity:minimal",
        "/nologo",
        "/m"
    )
    & $MsBuildPath @buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Build failed (exit code $LASTEXITCODE)."
        exit 1
    }
    Write-Success "Build succeeded."

    # Publish web project
    Write-Step "Publishing web project to $PublishDir..."
    $publishArgs = @(
        $WebProjectFile,
        "/p:Configuration=Release",
        "/p:DeployOnBuild=true",
        "/p:WebPublishMethod=Package",
        "/verbosity:minimal",
        "/nologo",
        "/m"
    )
    & $MsBuildPath @publishArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Publish failed (exit code $LASTEXITCODE)."
        exit 1
    }

    $packageTmp = Join-Path $repoRoot "src\PropertyManager.Web\obj\Release\Package\PackageTmp"
    if (Test-Path $packageTmp) {
        Copy-Item "$packageTmp\*" $PublishDir -Recurse -Force
        Write-Success "Publish artifacts copied to $PublishDir"
    } else {
        Write-Fail "Expected publish output not found at: $packageTmp"
        exit 1
    }
} else {
    Write-Header "Step 2 -- Build (SKIPPED)"
    if (-not (Test-Path $PublishDir) -or (Get-ChildItem $PublishDir -Recurse | Measure-Object).Count -eq 0) {
        Write-Fail "PublishDir is empty: $PublishDir. Cannot skip build."
        exit 1
    }
    Write-Success "Using existing artifacts in $PublishDir"
}

if ($DryRun) {
    Write-Header "Dry Run Complete"
    Write-Success "Build artifacts are in $PublishDir"
    Write-Warn "Deployment skipped (DryRun mode). Remove -DryRun to deploy."
    exit 0
}

# --- Step 3: Package ---
Write-Header "Step 3 -- Package"
Write-Step "Creating deployment zip: $ZipPath..."

if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force | Out-Null }
Compress-Archive -Path "$PublishDir\*" -DestinationPath $ZipPath -Force
$zipSizeMb = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
Write-Success "Zip created: $ZipPath - $($zipSizeMb) MB"

# --- Step 4: Database Migration (BACPAC) ---
Write-Header "Step 4 -- Database Migration (BACPAC)"

# Locate SqlPackage.exe
Write-Step "Locating SqlPackage.exe..."
$SqlPackagePath = Find-SqlPackage
if (-not $SqlPackagePath) {
    Write-Warn "SqlPackage.exe not found. Attempting install via dotnet tool..."
    $installResult = dotnet tool install -g microsoft.sqlpackage 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Failed to install SqlPackage via dotnet tool: $installResult"
        Write-Fail "Install manually: https://learn.microsoft.com/sql/tools/sqlpackage-download"
        exit 1
    }
    $SqlPackagePath = Find-SqlPackage
    if (-not $SqlPackagePath) {
        Write-Fail "SqlPackage.exe still not found after install. Check your PATH."
        exit 1
    }
}
Write-Success "SqlPackage found: $SqlPackagePath"

# Resolve Azure SQL target from Terraform
Write-Step "Resolving Azure SQL target from Terraform outputs..."
$SqlServerFqdn = Get-TerraformOutput -Name "sql_server_fqdn"
if (-not $SqlServerFqdn) {
    Write-Fail "Cannot detect SQL server FQDN from Terraform. Ensure 'task azure:up' has been run."
    exit 1
}
Write-Success "Target SQL Server: $SqlServerFqdn"

$SqlDatabaseName = Get-TerraformOutput -Name "sql_database_name"
if (-not $SqlDatabaseName) {
    Write-Fail "Cannot detect SQL database name from Terraform. Ensure 'task azure:up' has been run."
    exit 1
}
Write-Success "Target Database: $SqlDatabaseName"

# Export from local SQL Express
$BacpacPath = Join-Path $PublishDir "PropertyManager.bacpac"
Write-Step "Exporting local database to BACPAC..."
Write-Host "  Source: .\SQLEXPRESS / PropertyManager" -ForegroundColor DarkGray
Write-Host "  Output: $BacpacPath" -ForegroundColor DarkGray

if (Test-Path $BacpacPath) { Remove-Item $BacpacPath -Force }

$exportArgs = @(
    "/Action:Export",
    "/SourceServerName:.\SQLEXPRESS",
    "/SourceDatabaseName:PropertyManager",
    "/TargetFile:$BacpacPath"
)
& $SqlPackagePath @exportArgs
if ($LASTEXITCODE -ne 0) {
    Write-Fail "BACPAC export failed (exit code $LASTEXITCODE)."
    exit 1
}

if (-not (Test-Path $BacpacPath)) {
    Write-Fail "BACPAC file not found after export: $BacpacPath"
    exit 1
}
$bacpacSizeMb = [math]::Round((Get-Item $BacpacPath).Length / 1MB, 1)
Write-Success "BACPAC exported: $BacpacPath - $($bacpacSizeMb) MB"

# Get Entra ID access token for Azure SQL
Write-Step "Acquiring Entra ID access token for Azure SQL..."
$AccessToken = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or -not $AccessToken) {
    Write-Fail "Failed to acquire Entra ID access token for Azure SQL."
    Write-Fail "Ensure you are logged in with 'az login' and have permissions on the target database."
    exit 1
}
Write-Success "Access token acquired."

# Import BACPAC into Azure SQL
Write-Step "Importing BACPAC into Azure SQL..."
Write-Host "  Target: $SqlServerFqdn / $SqlDatabaseName" -ForegroundColor DarkGray
Write-Host "  (This typically takes 1-5 minutes depending on database size)" -ForegroundColor DarkGray

$importArgs = @(
    "/Action:Import"
    "/SourceFile:$BacpacPath"
    "/TargetServerName:tcp:${SqlServerFqdn},1433"
    "/TargetDatabaseName:$SqlDatabaseName"
    "/AccessToken:$AccessToken"
)
& $SqlPackagePath @importArgs
if ($LASTEXITCODE -ne 0) {
    Write-Fail "BACPAC import failed (exit code $LASTEXITCODE)."
    Write-Fail "Check that the Azure SQL firewall allows your IP and the database is empty."
    exit 1
}
Write-Success "Database imported successfully into Azure SQL."

# --- Step 5: Deploy ---
Write-Header "Step 5 -- Zip Deploy"
Write-Step "Deploying to $AppServiceName in $ResourceGroup..."
Write-Host "  (This typically takes 30-90 seconds)" -ForegroundColor DarkGray

Invoke-AzCli @(
    "webapp", "deploy",
    "--resource-group", $ResourceGroup,
    "--name", $AppServiceName,
    "--src-path", $ZipPath,
    "--type", "zip",
    "--async", "false",
    "--output", "none"
)
Write-Success "Zip deploy complete."

# --- Step 6: Update Connection String ---
Write-Header "Step 6 -- Connection String"
Write-Step "Reading SQL connection string from Terraform..."
$connStr = Get-TerraformOutput -Name "sql_connection_string"
if ($connStr) {
    Write-Step "Setting connection string on App Service..."
    Invoke-AzCli @(
        "webapp", "config", "connection-string", "set",
        "--resource-group", $ResourceGroup,
        "--name", $AppServiceName,
        "--settings", "PropertyManager=$connStr",
        "--connection-string-type", "SQLAzure",
        "--output", "none"
    )
    Write-Success "Connection string configured."
} else {
    Write-Warn "Could not read SQL connection string from Terraform outputs."
    Write-Warn "Set it manually: az webapp config connection-string set ..."
}

# --- Step 7: Restart & Verify ---
Write-Header "Step 7 -- Restart and Health Check"
Write-Step "Restarting App Service to apply configuration..."
Invoke-AzCli @(
    "webapp", "restart",
    "--resource-group", $ResourceGroup,
    "--name", $AppServiceName,
    "--output", "none"
)
Write-Success "App Service restarted."

Write-Step "Waiting 15 seconds for startup..."
Start-Sleep -Seconds 15

Write-Step "Checking health endpoint: $AppServiceUrl..."
try {
    $response = Invoke-WebRequest -Uri $AppServiceUrl -UseBasicParsing -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Success "App is live! Status: $($response.StatusCode)"
    } else {
        Write-Warn "App returned status: $($response.StatusCode) -- check logs."
    }
} catch {
    Write-Warn "Health check request failed: $_"
    Write-Warn "App may still be warming up. Run .\scripts\validate.ps1 to check."
}

# --- Summary ---
Write-Header "Migration Complete"
Write-Host ""
Write-Host "  App URL        : $AppServiceUrl" -ForegroundColor Cyan
Write-Host "  Resource Group : $ResourceGroup" -ForegroundColor Cyan
Write-Host "  App Service    : $AppServiceName" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    - Run .\scripts\validate.ps1 for full validation" -ForegroundColor White
Write-Host "    - Run .\scripts\compare.ps1 for cost comparison" -ForegroundColor White
Write-Host "    - Open Azure Portal → $AppServiceName → Application Insights" -ForegroundColor White
Write-Host ""
Write-Success "Deployment pipeline complete."


