---
name: "azure-sql-entra-import"
description: "Import BACPAC into Azure SQL using Entra ID (AAD) access token instead of SQL credentials"
domain: "cloud-deployment"
confidence: "high"
source: "earned"
---

## Context
When Azure SQL has Entra ID-only authentication enforced (by subscription policy or server config), you cannot use SQL username/password for SqlPackage imports. You must acquire an Entra ID access token and pass it via the `/AccessToken` parameter.

## Patterns

### Acquire token via Azure CLI
```powershell
$AccessToken = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv
```

### SqlPackage Import with access token
```powershell
$importArgs = @(
    "/Action:Import",
    "/SourceFile:$BacpacPath",
    "/TargetServerName:tcp:$SqlServerFqdn,1433",
    "/TargetDatabaseName:$SqlDatabaseName",
    "/AccessToken:$AccessToken"
)
& $SqlPackagePath @importArgs
```

### Finding SqlPackage.exe on Windows
1. Check PATH: `Get-Command "SqlPackage.exe" -ErrorAction SilentlyContinue`
2. Check glob: `C:\Program Files\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe`
3. Check glob: `C:\Program Files (x86)\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe`
4. Check dotnet global tools: `$env:USERPROFILE\.dotnet\tools\SqlPackage.exe`
5. Fallback install: `dotnet tool install -g microsoft.sqlpackage`

## Examples
See `scripts/migrate.ps1` Step 4 for the full working implementation.

## Anti-Patterns
- Do NOT use `/TargetUser` + `/TargetPassword` when Entra ID-only is enforced — it will fail with auth error
- Do NOT use storage account keys for intermediate BACPAC storage if subscription policy blocks key-based auth on storage
- Do NOT assume SqlPackage is on PATH — always check common install locations
- Tokens expire (~60 min) — for very large databases, consider `az sql db import` with SAS token or use streaming import
