<#
.SYNOPSIS
    Joins a Windows machine to the Active Directory domain.

.PARAMETER DomainName
    FQDN of the AD domain (e.g., bjdazure.tech)

.PARAMETER AdminUsername
    Domain admin username (without domain prefix).

.PARAMETER AdminPassword
    Domain admin password.

.NOTES
    Executed by Azure Custom Script Extension after the DC is promoted
    and VNet DNS is updated to point to the DC.
    The VM will reboot after joining the domain.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DomainName,

    [Parameter(Mandatory = $true)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $true)]
    [string]$AdminPassword
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\join-domain.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Output $Message
}

# ============================================================
# 1. Wait for DC to be reachable
# ============================================================
Write-Log "Waiting for domain controller to be reachable..."

$attempts = 0
$maxAttempts = 30
do {
    $attempts++
    $dcReachable = Test-Connection -ComputerName $DomainName -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $dcReachable) {
        Write-Log "  Attempt $attempts/$maxAttempts - DC not reachable, waiting 30s..."
        Start-Sleep -Seconds 30
    }
} while (-not $dcReachable -and $attempts -lt $maxAttempts)

if (-not $dcReachable) {
    Write-Log "ERROR: Domain controller not reachable after $maxAttempts attempts"
    exit 1
}

Write-Log "Domain controller is reachable"

# ============================================================
# 2. Join domain
# ============================================================
Write-Log "Joining domain: $DomainName"

$securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$DomainName\$AdminUsername", $securePassword)

Add-Computer -DomainName $DomainName -Credential $credential -Restart -Force

Write-Log "Domain join initiated -- VM will reboot"
