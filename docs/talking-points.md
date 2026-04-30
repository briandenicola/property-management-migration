# Client Talking Points — Azure Migrate Demo
## Property Manager: IIS VM → Azure App Service

**Audience:** Business + technical decision makers  
**Last Updated:** 2026-04-30T17:33:47.227Z

---

## Core Value Propositions

### 1. Eliminate Infrastructure Toil
**Message:** "Stop managing servers. Start managing your business."

- Every hour your team spends on OS patches, IIS updates, and disk cleanups is an hour not spent on features.
- Azure App Service is a fully managed platform. Microsoft handles the OS, runtime patches, load balancers, and network infrastructure.
- No RDP. No 2 AM reboots. No "who owns the SSL cert renewal?"

**Proof point:** A typical 3-person dev team spends 15–20% of capacity on infrastructure maintenance. App Service eliminates that category entirely.

---

### 2. Pay for What You Use, Scale When You Need It
**Message:** "Your VM is sized for peak. You're paying for peak 24/7. That changes today."

- A VM runs at the same cost whether it's handling 10 requests/hour or 10,000.
- App Service autoscale adds instances under load and removes them when load drops — automatically.
- Development and staging environments can run on cheaper tiers (B1/B2) and be scaled up only for load tests or releases.

**Proof point:** Many customers see 30–50% compute cost reduction after rightsizing from a general-purpose VM to an appropriately-tiered App Service plan.

---

### 3. Built-In Monitoring — From Blind to Instrumented in Minutes
**Message:** "Right now, you find out about problems when users call. That ends today."

- Application Insights provides: request rates, failure rates, response times, dependency calls, exceptions — all without code changes.
- Live Metrics stream: see what the app is doing *right now*, in real time.
- Smart detection: Azure ML flags anomalies (sudden spike in failures, degraded response times) before your users notice.
- Alert rules: "If failure rate > 2% for 5 minutes, page the on-call."

**Proof point:** Show the Application Insights Live Metrics stream during the demo — it's live immediately after deployment.

---

### 4. Enterprise SLA — Not Available on a Single VM
**Message:** "Your current uptime SLA is: 'we're trying our best.' Azure's is contractual."

| Setup | SLA | Fine print |
|---|---|---|
| Single Azure VM | 99.9% | Requires Premium storage |
| App Service (Standard+) | **99.95%** | Contractual, per Microsoft SLA |
| App Service + Deployment Slots | **99.95%** | With zero-downtime swap capability |

- Single-instance VMs have no SLA for planned maintenance windows.
- App Service Standard tier and above carries a 99.95% monthly uptime SLA — that's less than 22 minutes of downtime per month, guaranteed.

---

### 5. Security Posture: From Manual to Managed
**Message:** "HTTPS, managed identity, no passwords in config files."

- HTTPS is on by default. Free managed TLS certificates. Auto-renewal. Zero configuration.
- Managed Identity: the App Service authenticates to Azure SQL and Blob Storage using an Azure AD token — no passwords in connection strings, no secrets to rotate.
- Microsoft Defender for App Service: vulnerability scanning, threat detection, included in the plan.
- Azure Policy: enforce "no key-based storage auth," require HTTPS-only, tag compliance — centrally governed.

---

## Before / After Comparison Table

| Dimension | Legacy (IIS VM) | Modern (App Service) |
|---|---|---|
| **Infrastructure** | Windows Server 2016 VM (Standard_B2ms) | Managed PaaS — no VM to manage |
| **Patching** | Manual — OS + IIS + .NET separately | Fully managed by Microsoft |
| **Scaling** | Manual VM resize (causes downtime) | Autoscale: 1–10 instances in seconds |
| **Monitoring** | Windows Event Viewer, manual log review | Application Insights, Live Metrics, alerts |
| **Uptime SLA** | 99.9% (single VM, best case) | 99.95% contractual |
| **HTTPS / TLS** | Manual cert purchase + renewal | Free managed cert, auto-renewed |
| **Deployment** | RDP + robocopy | Zip deploy via CI/CD pipeline |
| **Deployment rollback** | VM snapshot (manual, hours) | Slot swap (instant, zero-downtime) |
| **Database** | SQL Server Express (10 GB cap, no HA) | Azure SQL with automatic backups, HA |
| **File storage** | Blobs in SQL database (anti-pattern) | Azure Blob Storage (geo-redundant) |
| **Secret management** | Passwords in web.config | Managed Identity + App Service settings |
| **Cost model** | Fixed (VM runs 24/7 at peak size) | Variable (pay per instance/hour) |
| **DR / Backup** | Manual VM snapshots | Automated backup to Blob Storage |

---

## TCO Discussion Points

### What the VM actually costs (total cost of ownership)

Most clients look at the Azure VM price and call it the cost. That's only the beginning:

| Cost category | VM model | App Service model |
|---|---|---|
| Compute | ~$70–120/mo (Standard_B2ms, Windows) | ~$75/mo (S1 Windows) |
| Windows Server license | Included in Azure VM pricing | Included in App Service |
| SQL Server | SQL Server Express (free, limited) vs. Standard ($$$) | Azure SQL S0 ~$15/mo |
| Patching labor | 4–8 hrs/mo @ your dev rate | $0 |
| Monitoring tooling | SCOM, Datadog, manual setup | App Insights included |
| SSL certificates | $100–300/cert/yr | Free (Let's Encrypt managed) |
| Backup tooling | Azure Backup agent, config, storage | Built-in, configured in portal |
| Incident response | On-call engineer, RDP, root-cause | Alert → auto-heal → deployment slot |

**Net result:** When you include labor, licensing, and tooling, the App Service model is typically cheaper — and dramatically lower-maintenance.

### Azure Hybrid Benefit
If the client has existing Windows Server or SQL Server licenses with Software Assurance, Azure Hybrid Benefit applies — potentially 40–85% cost reduction on the compute layer. Worth checking before quoting numbers.

---

## Common Objections and Responses

### "Our app has custom IIS modules / ISAPI filters."
**Response:** "Azure Migrate's compatibility assessment checks for exactly this. If it flagged nothing, you're clean. If there are custom native modules, we can often replace them with ASP.NET middleware — or use a custom container on App Service."

### "We have scheduled Windows tasks on that VM."
**Response:** "App Service has WebJobs and Azure Functions for background processing. Scheduled WebJobs are a direct equivalent. We'd migrate those scripts as part of the same engagement."

### "What about the database? Can we just move that too?"
**Response:** "Yes — Azure Database Migration Service handles SQL Server Express to Azure SQL with minimal downtime. We assess with Azure Migrate, migrate with DMS, and verify with our validation scripts. That's Act 5 in the migration story."

### "What if Azure goes down?"
**Response:** "Azure's regional SLA is 99.95% for App Service. For higher availability, we add geo-redundancy: two deployments in two regions behind Azure Front Door. That's an option on this platform that doesn't exist at all on a single on-premises VM."

### "We're not ready to re-architect. We just want to move it."
**Response:** "Perfect — that's exactly what this demo shows. Lift-and-shift. Same code, same .NET framework, same connection string format. Zero re-architecture. The modernization story (Blob Storage, managed identity, .NET 8) can be a phase 2 at your pace."

### "We have compliance requirements — data can't leave the region."
**Response:** "App Service and Azure SQL both support regional deployment with data residency constraints. We can pin everything to Canada Central (or your required region) and lock it down with Azure Policy."

### "Our team doesn't know Azure. Who manages this?"
**Response:** "Exactly the point — there's less to manage. Fewer moving parts than a VM. And what remains — deployment, scaling, monitoring — is through the Azure portal UI or Azure CLI. The learning curve is hours, not weeks."

### "How do we roll back if something goes wrong?"
**Response:** "Deployment slots: the new version goes to staging, you verify it, then swap. If anything's wrong post-swap, you swap back in 30 seconds. No VM snapshot restores, no rollback anxiety."

---

## Key Statistics to Cite

- **Migration time:** Under 10 minutes for a working .NET Framework app (as shown live)
- **Assessment time:** 24 hours for full discovery; Azure Migrate is free
- **App Service SLA:** 99.95% (vs. no SLA on a development VM)
- **Auto-heal:** App Service detects and recycles unhealthy app pools automatically — no human required
- **Scale time:** New instances provision in under 60 seconds
- **TLS:** Free managed certs via App Service Managed Certificates; no renewal action ever required

---

## The Migration Narrative (30-Second Elevator Pitch)

> "You have a working app on a Windows VM. It works fine — but you're maintaining the OS, managing the IIS config, handling your own cert renewals, and there's no auto-scale or real monitoring. Azure Migrate assessed your app in one day, found zero blockers, and we just moved it live in under 10 minutes. The app is now on App Service: HTTPS by default, Application Insights live, autoscale configured. Same .NET Framework 4.6.2. Same connection strings. Zero code changes. This is the lift. The shift comes next — at your pace."
