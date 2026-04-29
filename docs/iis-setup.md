# IIS Setup Guide — PropertyPro

> **Platform:** Windows Server 2012 R2 · IIS 8.5 · .NET Framework 4.6.1  
> **App:** PropertyPro Web API 2 + AngularJS SPA  
> **Deployment style:** xcopy / robocopy (no MSDeploy required)  
> **Last updated:** 2026-04-29

---

## Table of Contents

1. [Prerequisites — IIS Features & Modules](#1-prerequisites--iis-features--modules)
2. [App Pool Configuration](#2-app-pool-configuration)
3. [Site & Virtual Directory Setup](#3-site--virtual-directory-setup)
4. [File System Permissions](#4-file-system-permissions)
5. [Manual Deployment (xcopy style)](#5-manual-deployment-xcopy-style)
6. [Connection String Configuration (Production)](#6-connection-string-configuration-production)
7. [applicationHost.config Recommended Settings](#7-applicationhostconfig-recommended-settings)
8. [Post-Deployment Checklist](#8-post-deployment-checklist)
9. [Rollback Procedure](#9-rollback-procedure)
10. [Common Problems](#10-common-problems)

---

## 1. Prerequisites — IIS Features & Modules

Install these via **Server Manager → Add Roles and Features → Web Server (IIS)**.  
Run as Administrator.

### Required Windows Features

```
Web Server (IIS)
├── Common HTTP Features
│   ├── Default Document          ✓
│   ├── Directory Browsing        ✗  (disable — don't expose directory listings)
│   ├── HTTP Errors               ✓
│   ├── Static Content            ✓
│   └── HTTP Redirection          ✓
├── Health and Diagnostics
│   ├── HTTP Logging              ✓
│   └── Request Monitor           ✓ (useful for diagnosing hangs)
├── Performance
│   ├── Static Content Compression  ✓
│   └── Dynamic Content Compression ✓
├── Security
│   ├── Request Filtering         ✓  (enforces maxAllowedContentLength)
│   ├── Windows Authentication    ✓  (used by SQL Server pass-through if needed)
│   └── Anonymous Authentication  ✓  (app handles its own auth via OWIN)
├── Application Development
│   ├── .NET Extensibility 4.5    ✓
│   ├── ASP.NET 4.5               ✓
│   ├── ISAPI Extensions          ✓
│   └── ISAPI Filters             ✓
└── Management Tools
    └── IIS Management Console    ✓
```

PowerShell one-liner to install everything at once (run elevated):

```powershell
Install-WindowsFeature -Name Web-Server, Web-Default-Doc, Web-Http-Errors,
    Web-Static-Content, Web-Http-Redirect, Web-Http-Logging, Web-Request-Monitor,
    Web-Stat-Compression, Web-Dyn-Compression, Web-Filtering, Web-Windows-Auth,
    Web-App-Dev, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter,
    Web-Mgmt-Console -IncludeManagementTools
```

### Required Downloadable Modules

| Module | Version | Download | Why |
|--------|---------|----------|-----|
| **URL Rewrite 2.x** | 2.1 | [iis.net](https://www.iis.net/downloads/microsoft/url-rewrite) | AngularJS HTML5 pushState routing |
| **.NET Framework 4.6.1** | 4.6.1 | Windows Update / WSUS | Runtime for the app |

> **Note:** Do NOT install WebDAV. It conflicts with Web API PUT/DELETE verbs.  
> If it's already installed, disable the WebDAV module in IIS Manager or it will  
> intercept PUT requests before they reach Web API.

---

## 2. App Pool Configuration

Create a dedicated app pool — never use `DefaultAppPool`.

### Settings

| Setting | Value | Notes |
|---------|-------|-------|
| **Name** | `PropertyProPool` | |
| **.NET CLR Version** | `v4.0` | Targets .NET 4.6.1 (still CLR v4) |
| **Managed Pipeline Mode** | `Integrated` | Required for OWIN/Katana middleware |
| **Identity** | `ApplicationPoolIdentity` | Or a dedicated service account (preferred for prod) |
| **Start Mode** | `AlwaysRunning` | Prevents cold-start delays; requires IIS 8.5 Application Initialization module |
| **Idle Time-out** | `0` (disabled) | Keep alive — tenants hate the 20-second first-request lag |
| **Regular Time Interval (Recycle)** | `0` | Disable scheduled recycling (recycle manually during maintenance) |
| **Maximum Worker Processes** | `1` | Single worker — session state is InProc |

> **Why Integrated Pipeline?**  
> OWIN/Katana (`Microsoft.Owin.Host.SystemWeb`) requires Integrated Pipeline mode.  
> If you accidentally set this to Classic, you'll get a startup exception:  
> `"The IHttpModule and IHttpHandler interfaces require Integrated mode."`

### Creating the App Pool via PowerShell

```powershell
Import-Module WebAdministration

New-WebAppPool -Name "PropertyProPool"
Set-ItemProperty IIS:\AppPools\PropertyProPool -Name managedRuntimeVersion -Value "v4.0"
Set-ItemProperty IIS:\AppPools\PropertyProPool -Name managedPipelineMode    -Value "Integrated"
Set-ItemProperty IIS:\AppPools\PropertyProPool -Name processModel.idleTimeout -Value "00:00:00"
Set-ItemProperty IIS:\AppPools\PropertyProPool -Name recycling.periodicRestart.time -Value "00:00:00"
Set-ItemProperty IIS:\AppPools\PropertyProPool -Name startMode -Value "AlwaysRunning"
```

### Service Account (Production Recommended)

Create a low-privilege domain service account instead of using `ApplicationPoolIdentity`:

```powershell
# On the domain controller (or local if not domain-joined):
net user PropertyProSvc StrongPassword123! /add /comment:"PropertyPro IIS Service Account"
net localgroup IIS_IUSRS PropertyProSvc /add
```

Then in IIS Manager:  
App Pool → Advanced Settings → Process Model → Identity → Custom account → `DOMAIN\PropertyProSvc`

---

## 3. Site & Virtual Directory Setup

### Option A: New Dedicated Site (Recommended)

```powershell
Import-Module WebAdministration

$sitePath = "C:\inetpub\wwwroot\PropertyPro"
New-Item -ItemType Directory -Path $sitePath -Force

New-Website -Name "PropertyPro" `
            -Port 443 `
            -HostHeader "propertypro.yourcompany.com" `
            -PhysicalPath $sitePath `
            -ApplicationPool "PropertyProPool" `
            -Ssl

# HTTP → HTTPS redirect (URL Rewrite rule added via web.config)
New-WebBinding -Name "PropertyPro" -IPAddress "*" -Port 80 -HostHeader "propertypro.yourcompany.com"
```

### Option B: Application Under Default Web Site

If you can't get a dedicated binding (smaller deployments):

```powershell
New-WebApplication -Name "PropertyPro" `
                   -Site "Default Web Site" `
                   -PhysicalPath "C:\inetpub\wwwroot\PropertyPro" `
                   -ApplicationPool "PropertyProPool"
```

> **Note:** Running as a sub-application affects AngularJS routing. The `<base href>` in  
> `index.html` must match the virtual path (e.g., `<base href="/PropertyPro/">`), and  
> all Web API routes must be prefixed accordingly. Running as a root site is simpler.

### SSL Certificate

Bind an SSL certificate to port 443 in IIS Manager:  
Site → Bindings → Add → HTTPS → select certificate from the store.

For internal testing, a self-signed cert is fine:

```powershell
$cert = New-SelfSignedCertificate -DnsName "propertypro.yourcompany.com" -CertStoreLocation "cert:\LocalMachine\My"
```

---

## 4. File System Permissions

The app pool identity needs specific permissions. Wrong permissions = cryptic 500 errors.

### Site Root

```
C:\inetpub\wwwroot\PropertyPro\
```

| Identity | Permission | Reason |
|----------|-----------|--------|
| `IIS AppPool\PropertyProPool` | Read & Execute | Serve static files and run the app |
| `IUSR` | Read | Anonymous access to static content |
| `Administrators` | Full Control | Admin/ops management |

```powershell
$acl  = Get-Acl "C:\inetpub\wwwroot\PropertyPro"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "IIS AppPool\PropertyProPool", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
Set-Acl "C:\inetpub\wwwroot\PropertyPro" $acl
```

### App_Data Folder (EF LocalDB + Upload Temp)

The app writes to `App_Data` for EF LocalDB (dev) and the upload temp folder.  
The app pool identity needs **Modify** rights here.

```
C:\inetpub\wwwroot\PropertyPro\App_Data\
C:\inetpub\wwwroot\PropertyPro\App_Data\Uploads\
C:\inetpub\wwwroot\PropertyPro\App_Data\Uploads\Temp\
```

```powershell
$folders = @(
    "C:\inetpub\wwwroot\PropertyPro\App_Data",
    "C:\inetpub\wwwroot\PropertyPro\App_Data\Uploads",
    "C:\inetpub\wwwroot\PropertyPro\App_Data\Uploads\Temp"
)
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $acl  = Get-Acl $folder
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "IIS AppPool\PropertyProPool", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $folder $acl
}
Write-Host "Permissions set."
```

> **Why Modify on Temp?**  
> When a client uploads a file, ASP.NET buffers it to a temp path before the  
> `AttachmentService` reads and stores it in SQL Server. Without Modify permission  
> on the temp folder, uploads fail with a cryptic 500 (the real error is an  
> `UnauthorizedAccessException` buried in the Web API response buffer).

### Logs Folder

```powershell
icacls "C:\inetpub\logs\PropertyPro" /grant "IIS AppPool\PropertyProPool:(OI)(CI)M" /T
```

---

## 5. Manual Deployment (xcopy style)

This is a "copy files to the server" deployment — no MSDeploy, no WebDeploy packages,  
no CI/CD. Classic enterprise. Do it right and it's perfectly reliable.

### Step 1 — Build the Release

On your dev machine (or a build box), open a Visual Studio Developer Command Prompt:

```bat
msbuild PropertyPro.sln /p:Configuration=Release /p:DeployOnBuild=false /t:Build
```

Or build from Visual Studio: Build → Build Solution with **Release** configuration selected.

The compiled output lands in:
```
src\PropertyPro.Web\bin\
src\PropertyPro.Web\      (static files, views, web.config)
```

### Step 2 — Run the XDT Transform

The `web.Release.config` transform is automatically applied when building with `DeployOnBuild=true`,  
but for a manual xcopy deployment, apply it explicitly:

```powershell
# Using the WebConfigTransformRunner tool (install from NuGet or Chocolatey):
WebConfigTransformRunner.exe web.config web.Release.config web.config.transformed

# Review the output before copying:
notepad web.config.transformed
```

> **Always review the transformed web.config before deploying.**  
> Confirm `debug="false"` is absent and the connection string points to `PROD-SQL01`.

### Step 3 — Stage the Files

Create the deployment package on the build machine:

```bat
REM Create a clean staging folder
mkdir C:\Deploy\PropertyPro_staging

REM Copy the web project output
xcopy /E /I /Y src\PropertyPro.Web\*                   C:\Deploy\PropertyPro_staging\
xcopy /E /I /Y src\PropertyPro.Web\bin\*               C:\Deploy\PropertyPro_staging\bin\

REM Replace web.config with the transformed version
copy /Y web.config.transformed                          C:\Deploy\PropertyPro_staging\web.config

REM Do NOT copy App_Data (contains dev LocalDB, not for prod)
rmdir /S /Q C:\Deploy\PropertyPro_staging\App_Data
```

### Step 4 — Copy to Production Server

From the build machine (or via a network share):

```bat
REM Option A: robocopy over network share (recommended — preserves timestamps, retries)
robocopy C:\Deploy\PropertyPro_staging \\PROD-WEB01\wwwroot\PropertyPro ^
    /MIR /NP /LOG:C:\Deploy\deploy_log.txt ^
    /XD App_Data ^
    /XF *.log

REM Option B: plain xcopy over UNC path
xcopy /E /I /Y C:\Deploy\PropertyPro_staging\* \\PROD-WEB01\wwwroot\PropertyPro\
```

> `/MIR` mirrors the source to destination — it will DELETE files on the target  
> that no longer exist in the source. Good for keeping the server clean. Double-check  
> that `App_Data` and `Logs` are excluded before running.

### Step 5 — Recycle the App Pool

After copying, recycle the app pool to pick up the new binaries:

```powershell
# On PROD-WEB01 (Remote PowerShell or RDP):
Import-Module WebAdministration
Restart-WebAppPool -Name "PropertyProPool"

# Verify it came back up:
Get-WebAppPoolState -Name "PropertyProPool"   # Should show "Started"
```

Or via IIS Manager: Application Pools → PropertyProPool → Recycle.

> **Recycle vs. Stop+Start:**  
> Recycle does a graceful zero-downtime spin — IIS keeps the old worker process  
> alive for in-flight requests while the new one warms up. Stop+Start causes a  
> brief downtime. Always use Recycle for production unless you're debugging a  
> startup crash.

### Step 6 — Smoke Test

```powershell
# Hit the health check endpoint (if implemented):
Invoke-WebRequest -Uri "https://propertypro.yourcompany.com/api/health" -UseBasicParsing

# Check that the static SPA loads:
Invoke-WebRequest -Uri "https://propertypro.yourcompany.com/" -UseBasicParsing | Select-Object StatusCode
```

---

## 6. Connection String Configuration (Production)

**Do not put production credentials in web.config checked into source control.**

### Method A — IIS Manager (Encrypted in applicationHost.config)

1. IIS Manager → Sites → PropertyPro → **Connection Strings** (in Features View)
2. Add → Name: `PropertyProDb`, Custom: paste the connection string
3. IIS encrypts this in `applicationHost.config` using DPAPI (machine-key bound)

### Method B — aspnet_regiis Encryption (Recommended)

Encrypt the `<connectionStrings>` section directly in the deployed `web.config`  
using the machine's RSA key:

```bat
REM On PROD-WEB01, run elevated:
%windir%\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe ^
    -pe "connectionStrings" ^
    -app "/PropertyPro" ^
    -prov "RsaProtectedConfigurationProvider"
```

To decrypt (for reading/editing):
```bat
aspnet_regiis.exe -pd "connectionStrings" -app "/PropertyPro"
```

> The encrypted section is machine-specific. If you move the app to a new server,  
> you must decrypt first, then re-encrypt on the new machine. Export the RSA key  
> container if you need to share across multiple servers.

---

## 7. applicationHost.config Recommended Settings

Location: `C:\Windows\System32\inetsrv\config\applicationHost.config`

These settings go in the `<sites>` or `<applicationPools>` section of applicationHost.config.  
Edit via `appcmd.exe` or IIS Manager — **not** directly in the XML unless you know what you're doing.  
A typo in applicationHost.config takes down all sites on the server.

```xml
<!-- Recommended applicationHost.config snippets for PropertyPro -->
<!-- Apply these via appcmd or IIS Manager, not by hand-editing the file -->

<!-- App Pool: queue requests during recycle instead of returning 503 -->
<applicationPools>
  <add name="PropertyProPool"
       managedRuntimeVersion="v4.0"
       managedPipelineMode="Integrated"
       startMode="AlwaysRunning">
    <processModel
        identityType="ApplicationPoolIdentity"
        idleTimeout="00:00:00"
        maxProcesses="1"
        pingEnabled="true"
        pingInterval="00:00:30"
        pingResponseTime="00:01:30"
        shutdownTimeLimit="00:01:30"
        startupTimeLimit="00:01:30" />
    <recycling>
      <!-- Recycle at 2:00 AM on Sunday only — avoids mid-business-day recycling -->
      <periodicRestart time="00:00:00">
        <schedule>
          <clear />
          <!-- No scheduled recycling — recycle manually or on deploy -->
        </schedule>
      </periodicRestart>
      <logEventOnRecycle>Time,Requests,Schedule,Memory,IsapiUnhealthy,OnDemand,ConfigChange,PrivateMemory</logEventOnRecycle>
    </recycling>
    <failure
        rapidFailProtection="true"
        rapidFailProtectionInterval="00:05:00"
        rapidFailProtectionMaxCrashes="5"
        autoShutdownExe=""
        orphanWorkerProcess="false" />
  </add>
</applicationPools>

<!-- Site binding and application settings -->
<sites>
  <site name="PropertyPro" id="2">
    <application path="/" applicationPool="PropertyProPool">
      <virtualDirectory path="/" physicalPath="C:\inetpub\wwwroot\PropertyPro" />
    </application>
    <bindings>
      <binding protocol="https"
               bindingInformation="*:443:propertypro.yourcompany.com"
               sslFlags="0" />
      <binding protocol="http"
               bindingInformation="*:80:propertypro.yourcompany.com" />
    </bindings>
    <!-- Log to a dedicated folder, not the default IIS logs -->
    <logFile logFormat="W3C"
             directory="C:\inetpub\logs\PropertyPro"
             period="Daily"
             truncateSize="20971520"
             localTimeRollover="true"
             enabled="true" />
    <limits maxBandwidth="0" maxConnections="0" connectionTimeout="00:02:00" />
  </site>
</sites>
```

### appcmd equivalents (safer than hand-editing)

```bat
REM Set connection timeout to 2 minutes
%windir%\system32\inetsrv\appcmd set site "PropertyPro" /limits.connectionTimeout:00:02:00

REM Configure W3C logging to dedicated folder
%windir%\system32\inetsrv\appcmd set site "PropertyPro" /logFile.directory:"C:\inetpub\logs\PropertyPro"

REM Set rapid fail protection
%windir%\system32\inetsrv\appcmd set apppool "PropertyProPool" /failure.rapidFailProtection:true
%windir%\system32\inetsrv\appcmd set apppool "PropertyProPool" /failure.rapidFailProtectionMaxCrashes:5
```

---

## 8. Post-Deployment Checklist

Run through this after every deployment to production.

```
[ ] App pool is running (not stopped)
[ ] Site responds to HTTPS on port 443
[ ] HTTP (port 80) redirects to HTTPS
[ ] /api/health returns 200 (or first API call succeeds)
[ ] Login page loads (AngularJS SPA served from index.html)
[ ] File upload test: upload a JPEG < 1MB → should succeed
[ ] File upload test: upload a PDF ~20MB → should succeed
[ ] File upload test: upload a file > 25MB → should return 413 Request Entity Too Large
[ ] web.config: confirm debug attribute is NOT present (compilation section)
[ ] Event Log: no errors in Application log from source "PropertyPro" or "ASP.NET 4.0"
[ ] IIS Log: check C:\inetpub\logs\PropertyPro for any 500s
[ ] Connection string: points to PROD-SQL01, not LocalDB
[ ] Verify App_Data\Uploads\Temp folder exists and is writable
```

---

## 9. Rollback Procedure

We keep the previous deployment in a timestamped backup folder.

```bat
REM Before deploying, always snapshot the current deployment:
set TIMESTAMP=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%
set BACKUP=C:\Deploy\Backups\PropertyPro_%TIMESTAMP: =0%
robocopy C:\inetpub\wwwroot\PropertyPro %BACKUP% /MIR /NP /XD App_Data

REM To roll back:
robocopy %BACKUP% C:\inetpub\wwwroot\PropertyPro /MIR /NP /XD App_Data

REM Recycle after rollback:
%windir%\system32\inetsrv\appcmd recycle apppool "PropertyProPool"
```

> Keep the last 3 deployments as backups. Delete older ones to avoid filling the disk.

---

## 10. Common Problems

### 500.19 — Configuration Error (Cannot read configuration file)

**Cause:** Syntax error in web.config, or IIS can't access the file.  
**Fix:** Validate web.config XML. Check NTFS permissions on the web root.

### 404 on all API routes

**Cause:** Usually WebDAV interfering with extensionless URL routing.  
**Fix:** Confirm `WebDAVModule` is removed in web.config `<modules>` section. Disable WebDAV in IIS Manager for the site.

### 413 Request Entity Too Large on uploads UNDER 25MB

**Cause:** `maxAllowedContentLength` and `maxRequestLength` are out of sync, or IIS ARR/proxy is imposing its own limit.  
**Fix:** Confirm both values match: `maxRequestLength="25600"` (KB) and `maxAllowedContentLength="26214400"` (bytes). If behind ARR, update the ARR farm settings too.

### App pool keeps stopping (rapid fail protection)

**Cause:** Startup exception — usually a bad connection string or missing assembly.  
**Fix:** Check Windows Event Log → Application. The first-chance exception is logged there. Common culprit: wrong SQL Server name in connection string on a new server.

### AngularJS routes return 404 after direct URL entry

**Cause:** URL Rewrite module not installed, or rewrite rule not applied.  
**Fix:** Install URL Rewrite 2.x module. Verify the rewrite rule in web.config (`AngularJS HTML5 PushState` rule).

### File permissions error on upload (500 in logs)

**Cause:** `App_Data\Uploads\Temp` doesn't exist or the app pool identity lacks Modify rights.  
**Fix:** Create the folder and grant Modify to `IIS AppPool\PropertyProPool`. See §4.

### "The type initializer for ... threw an exception" on startup

**Cause:** Often a missing assembly binding redirect after a NuGet package update.  
**Fix:** In Visual Studio, run `Add-BindingRedirect` in Package Manager Console, rebuild, redeploy.
