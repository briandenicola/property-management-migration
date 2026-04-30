<#
.SYNOPSIS
    Production build script for PropertyManager web application.
.DESCRIPTION
    Restores NuGet packages, builds in Release configuration, and publishes
    the web project output to the publish/ folder for IIS deployment.
.EXAMPLE
    .\build.ps1
    .\build.ps1 -Configuration Debug
#>
param(
    [string]$Configuration = "Release",
    [string]$PublishDir = "$PSScriptRoot\publish"
)

$ErrorActionPreference = "Stop"

$msbuild = "C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
$solutionDir = "$PSScriptRoot\src"
$solutionFile = "$solutionDir\PropertyManager.sln"
$webProject = "$solutionDir\PropertyManager.Web\PropertyManager.Web.csproj"

# Validate MSBuild exists
if (-not (Test-Path $msbuild)) {
    Write-Error "MSBuild not found at: $msbuild"
    exit 1
}

# Validate solution exists
if (-not (Test-Path $solutionFile)) {
    Write-Error "Solution not found at: $solutionFile"
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " PropertyManager Production Build" -ForegroundColor Cyan
Write-Host " Configuration: $Configuration" -ForegroundColor Cyan
Write-Host " Publish To:    $PublishDir" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean publish output
Write-Host "[1/4] Cleaning publish directory..." -ForegroundColor Yellow
if (Test-Path $PublishDir) {
    Remove-Item -Recurse -Force $PublishDir
}
New-Item -ItemType Directory -Path $PublishDir -Force | Out-Null
Write-Host "  Done." -ForegroundColor Green

# Step 2: Restore NuGet packages
Write-Host "[2/4] Restoring NuGet packages..." -ForegroundColor Yellow
& $msbuild $solutionFile /t:Restore /p:RestorePackagesConfig=true /verbosity:minimal /nologo
if ($LASTEXITCODE -ne 0) {
    # Fallback: use nuget.exe if available, or MSBuild package restore via solution-level restore
    Write-Host "  MSBuild restore failed, attempting packages.config restore..." -ForegroundColor Yellow
    & $msbuild $solutionFile /t:Build /p:Configuration=$Configuration /p:RestorePackages=true /verbosity:minimal /nologo /m
    if ($LASTEXITCODE -ne 0) {
        Write-Error "NuGet package restore failed."
        exit 1
    }
} else {
    Write-Host "  Done." -ForegroundColor Green
}

# Step 3: Build solution in Release
Write-Host "[3/4] Building solution ($Configuration)..." -ForegroundColor Yellow
& $msbuild $solutionFile /t:Build /p:Configuration=$Configuration /verbosity:minimal /nologo /m
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed."
    exit 1
}
Write-Host "  Done." -ForegroundColor Green

# Step 4: Publish web project
Write-Host "[4/4] Publishing web project to $PublishDir..." -ForegroundColor Yellow
& $msbuild $webProject /p:Configuration=$Configuration `
    /p:DeployOnBuild=true `
    /p:PublishProfile=FileSystem `
    /p:publishUrl=$PublishDir `
    /p:DeleteExistingFiles=true `
    /verbosity:minimal /nologo /m
if ($LASTEXITCODE -ne 0) {
    Write-Error "Publish failed."
    exit 1
}
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " BUILD SUCCESSFUL" -ForegroundColor Green
Write-Host " Output: $PublishDir" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deployment notes:" -ForegroundColor Yellow
Write-Host "  1. Copy the publish/ folder contents to IIS site root"
Write-Host "  2. Replace connection string placeholders in web.config:"
Write-Host "     #{DatabaseServer}#  -> your SQL Server hostname"
Write-Host "     #{DatabaseName}#    -> PropertyManagerLegacy"
Write-Host "     #{DatabaseUser}#    -> SQL login username"
Write-Host "     #{DatabasePassword}# -> SQL login password"
Write-Host ""
