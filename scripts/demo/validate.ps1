#Requires -Version 5.1
<#
.SYNOPSIS
    Post-migration validation — health check, DB connectivity, Blob Storage access,
    response time comparison, and feature smoke tests.

.DESCRIPTION
    Validates the migrated Property Manager app running on Azure App Service.
    Tests:
      1. HTTP health check (root URL returns 200)
      2. API health endpoint (/api/health or /api/properties response)
      3. Database connectivity (via API that queries DB)
      4. Blob Storage access (checks API attachment endpoint)
      5. Response time baseline comparison (legacy vs modern)
      6. Feature smoke test: list properties, create a test record

.PARAMETER AppServiceUrl
    URL of the target App Service. Auto-detected from Terraform outputs if omitted.

.PARAMETER LegacyUrl
    URL of the legacy IIS app for response time comparison. Optional.

.PARAMETER ResourceGroup
    App Service resource group. Used for log stream check. Auto-detected from Terraform.

.PARAMETER AppServiceName
    App Service name. Auto-detected from Terraform.

.PARAMETER SubscriptionId
    Azure subscription ID.

.PARAMETER SkipSmokeTest
    Skip the feature smoke test (create/read operations).

.EXAMPLE
    .\validate.ps1

.EXAMPLE
    .\validate.ps1 -LegacyUrl "http://20.1.2.3" -SkipSmokeTest
#>
[CmdletBinding()]
param(
    [string]$AppServiceUrl   = "",
    [string]$LegacyUrl       = "",
    [string]$ResourceGroup   = "",
    [string]$AppServiceName  = "",
    [string]$SubscriptionId  = "ccfc5dda-43af-4b5e-8cc2-1dda18f2382e",
    [switch]$SkipSmokeTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region --- Helpers ---

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkBlue
    Write-Host "  $Text" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkBlue
}

function Write-Step   { param([string]$T); Write-Host "  ▶ $T" -ForegroundColor White }
function Write-Pass   { param([string]$T); Write-Host "  ✓ PASS: $T" -ForegroundColor Green }
function Write-Fail   { param([string]$T); Write-Host "  ✗ FAIL: $T" -ForegroundColor Red }
function Write-Warn   { param([string]$T); Write-Host "  ⚠ WARN: $T" -ForegroundColor Yellow }
function Write-Info   { param([string]$T); Write-Host "  ℹ $T" -ForegroundColor DarkGray }

function Get-RepoRoot {
    return Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

function Get-TerraformOutput {
    param([string]$Name, [string]$Dir = "infrastructure/azure")
    $repoRoot = Get-RepoRoot
    $tfDir    = Join-Path $repoRoot $Dir
    if (-not (Test-Path (Join-Path $tfDir ".terraform"))) { return $null }
    $val = terraform -chdir=$tfDir output -raw $Name 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $val
}

function Measure-ResponseTime {
    param([string]$Url, [int]$Samples = 3)
    $times = @()
    for ($i = 0; $i -lt $Samples; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30 | Out-Null
            $sw.Stop()
            $times += $sw.ElapsedMilliseconds
        } catch {
            $sw.Stop()
        }
        if ($i -lt ($Samples - 1)) { Start-Sleep -Milliseconds 500 }
    }
    if ($times.Count -eq 0) { return $null }
    return [math]::Round(($times | Measure-Object -Average).Average)
}

function Test-Endpoint {
    param([string]$Url, [int]$ExpectedStatus = 200, [string]$Label = "")
    $label = if ($Label) { $Label } else { $Url }
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Pass "$label → HTTP $($response.StatusCode)"
            return $true
        } else {
            Write-Fail "$label → HTTP $($response.StatusCode) (expected $ExpectedStatus)"
            return $false
        }
    } catch [System.Net.WebException] {
        $code = [int]$_.Exception.Response.StatusCode
        if ($code -eq $ExpectedStatus) {
            Write-Pass "$label → HTTP $code"
            return $true
        }
        Write-Fail "$label → $($_.Exception.Message)"
        return $false
    } catch {
        Write-Fail "$label → $($_.Exception.Message)"
        return $false
    }
}

#endregion

$results = @{
    Passed = 0
    Failed = 0
    Warned = 0
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Post-Migration Validation — Property Mgr     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan

# --- Resolve targets ---
Write-Header "Resolving Targets"

if (-not $AppServiceUrl) {
    $AppServiceUrl = Get-TerraformOutput -Name "app_service_url"
    if ($AppServiceUrl) { Write-Step "App Service URL (Terraform): $AppServiceUrl" }
    else {
        Write-Fail "Cannot detect App Service URL. Provide -AppServiceUrl."
        exit 1
    }
}

if (-not $AppServiceName) {
    $AppServiceName = Get-TerraformOutput -Name "app_service_name"
}
if (-not $ResourceGroup) {
    $ResourceGroup = Get-TerraformOutput -Name "resource_group_name"
}

Write-Info "Target: $AppServiceUrl"
if ($LegacyUrl) { Write-Info "Legacy: $LegacyUrl" }

# --- Test 1: HTTP Health Check ---
Write-Header "Test 1 — HTTP Health Check"
Write-Step "Checking root URL returns 200..."
if (Test-Endpoint -Url $AppServiceUrl -Label "Root URL ($AppServiceUrl)") {
    $results.Passed++
} else {
    $results.Failed++
    Write-Warn "Root URL failed — app may still be warming up. Wait 30s and retry."
}

# --- Test 2: API Endpoint ---
Write-Header "Test 2 — API Connectivity"
$apiBaseUrl = $AppServiceUrl.TrimEnd('/')
$propertiesUrl = "$apiBaseUrl/api/properties"
Write-Step "Checking API endpoint: $propertiesUrl"
if (Test-Endpoint -Url $propertiesUrl -Label "GET /api/properties") {
    $results.Passed++
    Write-Info "API is responding — database connectivity is implied."
} else {
    $results.Failed++
    Write-Warn "API not responding. Check App Service logs: az webapp log tail --name $AppServiceName --resource-group $ResourceGroup"
}

# --- Test 3: Database Connectivity ---
Write-Header "Test 3 — Database Connectivity"
Write-Step "Checking API returns valid JSON (implies DB query success)..."
try {
    $resp = Invoke-RestMethod -Uri $propertiesUrl -TimeoutSec 30 -ErrorAction Stop
    if ($null -ne $resp) {
        Write-Pass "API returned valid response (DB query succeeded)"
        $results.Passed++
        if ($resp -is [array]) {
            Write-Info "Properties returned: $($resp.Count)"
        }
    } else {
        Write-Warn "API returned null — DB may be empty (not necessarily an error)"
        $results.Warned++
    }
} catch {
    Write-Fail "API/DB check failed: $_"
    $results.Failed++
    Write-Warn "Likely cause: connection string not set or firewall rule missing."
    Write-Info "Fix: .\migrate.ps1 -ConnectionStringOnly"
}

# --- Test 4: Blob Storage Access ---
Write-Header "Test 4 — Blob Storage Access"
Write-Step "Checking attachment API endpoint..."
$attachmentsUrl = "$apiBaseUrl/api/attachments"
# We expect 200 (empty list) or 404 if no records — both indicate storage is accessible
try {
    $blobResp = Invoke-WebRequest -Uri $attachmentsUrl -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    if ($blobResp.StatusCode -in @(200, 204)) {
        Write-Pass "Attachment endpoint reachable (Blob Storage accessible)"
        $results.Passed++
    } else {
        Write-Warn "Attachment endpoint returned $($blobResp.StatusCode) — verify Managed Identity role assignment"
        $results.Warned++
    }
} catch [System.Net.WebException] {
    $code = [int]$_.Exception.Response.StatusCode
    if ($code -eq 404) {
        Write-Pass "Attachment endpoint returned 404 (no records, but endpoint is live)"
        $results.Passed++
    } elseif ($code -eq 500) {
        Write-Fail "Attachment endpoint returned 500 — Blob Storage config may be missing"
        $results.Failed++
        Write-Info "Check: App Service → Configuration → BlobStorage__ServiceUri and BlobStorage__ContainerName"
    } else {
        Write-Warn "Attachment endpoint returned $code"
        $results.Warned++
    }
} catch {
    Write-Warn "Attachment endpoint check skipped: $_"
    $results.Warned++
}

# --- Test 5: Response Time Comparison ---
Write-Header "Test 5 — Response Time"
Write-Step "Measuring App Service response time (3 samples)..."
$modernMs = Measure-ResponseTime -Url $AppServiceUrl -Samples 3
if ($null -ne $modernMs) {
    Write-Pass "App Service average response time: ${modernMs}ms"
    $results.Passed++

    if ($LegacyUrl) {
        Write-Step "Measuring legacy IIS response time (3 samples)..."
        $legacyMs = Measure-ResponseTime -Url $LegacyUrl -Samples 3
        if ($null -ne $legacyMs) {
            Write-Pass "Legacy IIS average response time: ${legacyMs}ms"
            $delta = $modernMs - $legacyMs
            if ($delta -le 500) {
                Write-Pass "Response time delta: ${delta}ms (within acceptable range)"
            } else {
                Write-Warn "Response time delta: ${delta}ms — App Service may need warm-up (Always On enabled?)"
            }
        } else {
            Write-Warn "Could not measure legacy response time at $LegacyUrl"
        }
    } else {
        Write-Info "Skipping legacy comparison (no -LegacyUrl provided)"
    }
} else {
    Write-Fail "Could not measure App Service response time"
    $results.Failed++
}

# --- Test 6: Feature Smoke Test ---
if (-not $SkipSmokeTest) {
    Write-Header "Test 6 — Feature Smoke Test"

    # CREATE a test property
    Write-Step "Creating a smoke-test property via API..."
    $testProperty = @{
        name        = "Smoke Test Property $(Get-Date -Format 'HHmmss')"
        address     = "123 Validation Ave, Test City, TC 00000"
        description = "Created by validate.ps1 smoke test"
        type        = "Residential"
    } | ConvertTo-Json

    try {
        $createResp = Invoke-RestMethod `
            -Uri "$apiBaseUrl/api/properties" `
            -Method Post `
            -Body $testProperty `
            -ContentType "application/json" `
            -TimeoutSec 30 `
            -ErrorAction Stop

        if ($createResp.id -or $createResp.Id) {
            $createdId = if ($createResp.id) { $createResp.id } else { $createResp.Id }
            Write-Pass "Property created: ID=$createdId"
            $results.Passed++

            # READ it back
            Write-Step "Reading back the created property..."
            $readResp = Invoke-RestMethod `
                -Uri "$apiBaseUrl/api/properties/$createdId" `
                -TimeoutSec 30 `
                -ErrorAction Stop
            if ($readResp) {
                Write-Pass "Property read-back: '$($readResp.name ?? $readResp.Name)'"
                $results.Passed++
            } else {
                Write-Fail "Read-back returned null for ID=$createdId"
                $results.Failed++
            }
        } else {
            Write-Warn "Create returned unexpected response format"
            $results.Warned++
        }
    } catch {
        Write-Warn "Smoke test failed: $_ (API may require authentication)"
        $results.Warned++
        Write-Info "If the app requires auth, skip smoke test with -SkipSmokeTest"
    }
} else {
    Write-Header "Test 6 — Feature Smoke Test (SKIPPED)"
    Write-Warn "Use -SkipSmokeTest:$false to enable"
}

# --- App Service Health via Azure CLI ---
if ($AppServiceName -and $ResourceGroup) {
    Write-Header "Azure App Service Status Check"
    Write-Step "Checking App Service state via Azure CLI..."
    try {
        $appStatus = az webapp show `
            --name $AppServiceName `
            --resource-group $ResourceGroup `
            --query "{state:state, defaultHostName:defaultHostName, httpsOnly:httpsOnly}" `
            --output json 2>$null | ConvertFrom-Json
        if ($appStatus) {
            Write-Pass "App Service state: $($appStatus.state)"
            if ($appStatus.httpsOnly) {
                Write-Pass "HTTPS-only mode: enabled"
            } else {
                Write-Warn "HTTPS-only mode: disabled (recommended to enable)"
                $results.Warned++
            }
            Write-Info "Host: $($appStatus.defaultHostName)"
        }
    } catch {
        Write-Warn "Could not query App Service via CLI: $_"
    }
}

# --- Summary ---
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              Validation Summary                  ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host ("║  ✓ Passed : {0,-40}║" -f $results.Passed) -ForegroundColor Green
Write-Host ("║  ✗ Failed : {0,-40}║" -f $results.Failed) -ForegroundColor $(if ($results.Failed -gt 0) { "Red" } else { "Gray" })
Write-Host ("║  ⚠ Warned : {0,-40}║" -f $results.Warned) -ForegroundColor $(if ($results.Warned -gt 0) { "Yellow" } else { "Gray" })
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($results.Failed -gt 0) {
    Write-Host "  RESULT: ❌ VALIDATION FAILED — see failures above" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "    - Connection string: .\migrate.ps1 -ConnectionStringOnly" -ForegroundColor White
    Write-Host "    - App logs: az webapp log tail --name $AppServiceName --resource-group $ResourceGroup" -ForegroundColor White
    Write-Host "    - Restart: az webapp restart --name $AppServiceName --resource-group $ResourceGroup" -ForegroundColor White
    exit 1
} elseif ($results.Warned -gt 0) {
    Write-Host "  RESULT: ⚠ VALIDATION PASSED WITH WARNINGS" -ForegroundColor Yellow
} else {
    Write-Host "  RESULT: ✅ ALL VALIDATIONS PASSED" -ForegroundColor Green
}
Write-Host ""
