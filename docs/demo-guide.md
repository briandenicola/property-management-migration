# Azure Migrate Demo Guide
## IIS VM → App Services: Live Migration Walkthrough

**Audience:** Client stakeholders (technical + business)  
**Total Runtime:** ~18 minutes  
**Presenter:** Brian  
**Last Updated:** 2026-04-30T17:33:47.227Z

---

## Prerequisites

### Tools Required on Presenter Machine
- Azure CLI (`az --version` ≥ 2.57)
- PowerShell 7+ (for scripts)
- RDP client (mstsc)
- Browser (Edge/Chrome) — two tabs pre-opened
- Task runner: `task` CLI installed

### Azure Resources (pre-provisioned)
| Resource | How to verify |
|---|---|
| Legacy VM + IIS | `task legacy:creds` → RDP in, browse to `iis_url` |
| App Service (target) | `task azure:up` has been run |
| Azure SQL | `terraform output -raw sql_server_fqdn` (from `infrastructure/azure/`) |
| Azure Migrate project | Created by `scripts/demo/assess.ps1` the day before |

### Day-Before Prep Checklist
- [ ] Run `task legacy:up` — confirm VM is running and IIS app is live
- [ ] Run `task azure:up` — confirm App Service, SQL, and Storage are provisioned
- [ ] Run `scripts/demo/assess.ps1` — creates Azure Migrate project and pre-stages assessment
- [ ] Open Azure Portal and navigate to Azure Migrate project — verify assessment shows results
- [ ] RDP into legacy VM once to confirm app loads at `http://<vm-ip>/`
- [ ] Pre-open two browser tabs: (1) legacy IIS URL, (2) Azure Migrate portal blade
- [ ] Run `scripts/demo/migrate.ps1 -DryRun` — confirm build succeeds without deploying
- [ ] Run `scripts/demo/validate.ps1 -LegacyUrl http://<vm-ip>` — confirm legacy baseline metrics
- [ ] Print or screen-share `scripts/demo/compare.ps1` output as backup talking points
- [ ] Charge laptop, disable screen lock, close Slack/Teams notifications

---

## Act 1 — The Legacy App (3 minutes)
> **Narrative:** "Let me show you where they are today."

### 1.1 — Open the Legacy App (0:00–1:00)

**Action:** Browse to `http://<legacy-vm-ip>/` (pre-opened tab)

**Talking points:**
- "This is the property management system running right now — Windows Server 2016, IIS 10, .NET Framework 4.6.2."
- "It works. Staff use it every day. But it's running on a VM that your team has to patch, reboot, and babysit."
- "The database is SQL Server Express — which has a 10 GB cap and no HA story."
- "Attachments — PDFs, inspection photos — are stored as blobs directly in the database. That's the pattern we're here to modernize."

**What to click:** Load the app, browse to Maintenance Requests, open one with an attachment.

**Fallback:** If VM is unreachable → show screenshot in `docs/screenshots/legacy-app.png`.

---

### 1.2 — RDP Into the VM (1:00–2:30)

**Action:** Run `task legacy:creds` in terminal → copy RDP string → `mstsc /v:<ip>:3389`

```powershell
# Get credentials
cd infrastructure/legacy
terraform output rdp_connection_string
terraform output vm_admin_username
terraform output -raw vm_admin_password
```

**Talking points (while RDP connects):**
- "To manage anything on this server — a config change, a certificate, a hotfix — someone has to RDP in. That's 2 AM on a Saturday if something breaks."
- "There's no auto-scale. Black Friday, lease renewal season, heavy report runs — the VM is what it is."

**What to show in RDP:**
1. Open IIS Manager → show site binding, app pool
2. Open Windows Event Viewer → note the manual log hunting experience
3. Open Services → point to SQL Server Express service

**Fallback:** Skip RDP if connectivity is slow. Jump directly to Act 2.

---

### 1.3 — Close the Loop (2:30–3:00)

**Talking points:**
- "Good news: it works. Bad news: the operational burden is entirely on your team."
- "Let's look at what Azure Migrate found when it assessed this workload."

---

## Act 2 — Azure Migrate Assessment (5 minutes)
> **Narrative:** "The assessment tells us *exactly* what we're moving and what it'll look like on the other side."

### 2.1 — Open Azure Migrate in Portal (3:00–4:00)

**Action:** Switch to pre-opened browser tab → Azure Portal → Azure Migrate

Navigate to: `portal.azure.com` → search "Azure Migrate" → open project `property-mgmt-migrate`

**Talking points:**
- "Azure Migrate is Microsoft's free assessment and migration platform. We ran discovery against the VM last night — it's been cataloguing the app, dependencies, and sizing."
- "This isn't guesswork. It's fingerprinting: OS, IIS bindings, .NET version, application pool config, connection strings."

**Fallback:** If portal is slow → open `scripts/demo/assess.ps1` output JSON from previous run.

---

### 2.2 — Walk Through Assessment Results (4:00–6:30)

**Navigate to:** Azure Migrate → Web App Assessment blade

**What to show and say:**

| Portal section | Talking point |
|---|---|
| **Discovered apps** | "One site: PropertyManager on port 80. IIS 10, .NET 4.6.2, integrated pipeline — all catalogued automatically." |
| **Readiness** | "Green: Ready for App Service. No blocking issues detected." |
| **Recommended SKU** | "It recommends B2 or S1 — matches what we provisioned for the target." |
| **Migration warnings** | "Any yellow items here are advisory — things to verify, not blockers. We'll address them in the validation step." |
| **Cost estimate** | "Side by side: VM + patching + SQL licenses vs. App Service + Azure SQL. We'll go deeper on that in a moment." |

**Talking points:**
- "What Azure Migrate is doing here is reading the IIS metabase directly — app pool identity, CLR version, managed pipeline mode — and mapping it to an App Service equivalent configuration."
- "The key finding: this app is a clean lift. No GAC dependencies, no COM objects, no custom ISAPI filters."

**Fallback:** If assessment data is incomplete → use `scripts/demo/compare.ps1` output to narrate the comparison manually.

---

### 2.3 — Export Assessment (6:30–8:00)

**Action:** Click "Export assessment" → download CSV

**Talking points:**
- "You'll get a copy of this report. It becomes your migration business case — for budget approval, change management, or just the architectural record."

---

## Act 3 — Live Migration with Migration Assistant (8:00–13:00)
> **Narrative:** "Now let's actually move it."

### 3.1 — Launch App Service Migration Assistant (8:00–9:00)

> **Note:** App Service Migration Assistant must be installed on the legacy VM. Install from: `https://azure.microsoft.com/en-us/products/app-service/migration-tools/`

**Action:** RDP back into VM → launch "App Service Migration Assistant" from desktop

**Talking points:**
- "The Migration Assistant runs on the source machine. It reads the IIS config, does a final compatibility check, and orchestrates the deployment to App Service — all in one wizard."
- "In a real engagement, you'd install this during the discovery phase. We pre-staged it yesterday."

**Fallback if Migration Assistant fails or hangs:** Jump immediately to Section 3.3 (scripted fallback). Say: "We also have our own deployment script, which is what CI/CD would use in production — let me run that instead."

---

### 3.2 — Walk Through Migration Assistant Wizard (9:00–12:00)

**Steps to follow in the wizard:**

1. **Select site:** Choose `PropertyManager` → Next
2. **Compatibility check:** Should show green/all passed. If warnings appear:
   - `PortabilityAnalysis` warning → explain: "This is the 32-bit app pool — App Service handles this automatically"
   - `CustomHeaders` warning → explain: "We preserve these in the App Service configuration"
3. **Azure sign-in:** Sign in with demo account
4. **Select target:**
   - Subscription: `ccfc5dda-43af-4b5e-8cc2-1dda18f2382e`
   - Resource Group: *(use `terraform output resource_group_name` from `infrastructure/azure/`)*
   - App Service: *(use `terraform output app_service_name` from `infrastructure/azure/`)*
5. **Connection strings:** The wizard will prompt. Enter values from `terraform output -raw sql_connection_string`
6. **Migrate:** Click Migrate → watch progress bar

**Talking points during migration:**
- "It's packaging the app, zipping it, and doing a zip-deploy to App Service. The same thing our CI/CD pipeline will do on every release."
- "Notice: no downtime on the source. The VM is still running. We could have run both in parallel for a week before cutover."

---

### 3.3 — Fallback: Scripted Migration (if Migration Assistant fails) (9:00–12:00)

**Action:** Open PowerShell on presenter machine, run:

```powershell
cd C:\Users\brdenico\Code\property-management-migration

# Get target details from Terraform
$rg  = terraform -chdir=infrastructure/azure output -raw resource_group_name
$app = terraform -chdir=infrastructure/azure output -raw app_service_name

# Run the fallback migration
.\scripts\demo\migrate.ps1 -ResourceGroup $rg -AppServiceName $app
```

**Talking points:**
- "This is the script our CI/CD pipeline uses. Build, package, zip-deploy — reproducible every time."
- "The build takes about 90 seconds on this machine. In a pipeline it runs in parallel on a cloud agent."

**Watch for:** Build output scrolling — call out "NuGet restore, compile, publish" stages.

---

## Act 4 — The App on App Service (13:00–18:00)
> **Narrative:** "Same app. Different world."

### 4.1 — Open the App on App Service (13:00–14:00)

**Action:** Run validation script or browse directly:

```powershell
$url = terraform -chdir=infrastructure/azure output -raw app_service_url
Start-Process $url
```

**Talking points:**
- "HTTPS by default. Managed certificate. No certificate renewal task on your calendar ever again."
- "Custom domain? Two DNS records and you're done."

**Fallback:** If app returns 500 on first load → run `.\scripts\demo\validate.ps1` to triage. Common cause: connection string not yet set. See `migrate.ps1` output.

---

### 4.2 — Show Azure Portal Features (14:00–16:30)

Navigate through these portal blades for the App Service:

| Blade | What to show | Talking point |
|---|---|---|
| **Overview** | Running state, URL, .NET version | "One pane — health, URL, runtime. No RDP needed." |
| **Application Insights** | Live Metrics stream | "Real-time telemetry. Request rate, failure rate, response time — visible in seconds after deploy." |
| **Scale out (App Service Plan)** | Manual scale slider | "Need to handle a surge? Slide to 3 instances. Takes 60 seconds. Slide back when done." |
| **Autoscale** | Rules configuration | "Or set rules: scale out when CPU > 70% for 5 minutes, scale in when < 30%. Fully automated." |
| **Backups** | Backup configuration | "Daily backups to Blob Storage. Point-in-time restore. No DBA required." |
| **Deployment slots** | Staging slot | "Blue/green deployments built in. Test in staging, swap to production — zero downtime." |
| **Diagnose and solve problems** | Auto-heal, crash dumps | "If something breaks, this surfaces it before your users call." |

---

### 4.3 — Run the Comparison Report (16:30–17:30)

**Action:**

```powershell
.\scripts\demo\compare.ps1 -LegacyVmSize "Standard_B2ms" -AppServiceSku "S1"
```

**Walk through output:**
- Monthly cost delta
- Feature comparison table
- SLA comparison (no SLA on single VM vs. 99.95% App Service SLA)

**Talking points:**
- "The VM is about $X/month — but that's just compute. Add patching labor, SQL Server CAL, backup tooling, monitoring agents..."
- "App Service S1 is $Y/month. All-in. Backups, monitoring, SSL, autoscale — included."

---

### 4.4 — Close (17:30–18:00)

**Talking points:**
- "We moved a real production app — not a toy — from IIS on a Windows Server VM to Azure App Service in under 10 minutes."
- "The migration story doesn't end here. Next chapter: swap the SQL Server blobs to Azure Blob Storage, add CDN, enable geo-redundancy."
- "But today you can walk away knowing: the lift is real, it works, and Azure Migrate gives you the assessment receipts to justify it."

**Call to action:** "What questions do you have? What's the workload you're most worried about migrating?"

---

## Emergency Procedures

### App won't load on App Service
1. Check `.\scripts\demo\validate.ps1` output — pinpoints connection/config issues
2. Check App Service → Log stream in portal
3. If connection string missing: re-run `.\scripts\demo\migrate.ps1 -ConnectionStringOnly`
4. Nuclear option: `az webapp restart --name <app> --resource-group <rg>`

### Legacy VM unreachable
1. Check Azure Portal → VM → Overview → Start if stopped
2. Check NSG: your current IP must match the RDP rule
3. Skip Act 1 RDP portion — use pre-cached screenshots

### Azure Portal slow / down
1. Use Azure CLI for all outputs: `az webapp show`, `az monitor app-insights`
2. Run `.\scripts\demo\compare.ps1` for numbers
3. Show Application Insights → Azure Monitor in portal (different URL: `monitor.azure.com`)

### Build fails in migrate.ps1
1. Confirm MSBuild path: `"C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe"`
2. Run `task restore` first: NuGet packages might need restoring
3. Check `.\publish\` — if it exists from a prior run, zip-deploy can use it directly:
   ```powershell
   .\scripts\demo\migrate.ps1 -SkipBuild
   ```
