<#
.SYNOPSIS
    Promotes a Windows Server to Active Directory Domain Controller.
    Creates a new forest and configures DNS, OUs, groups, and demo users.

.PARAMETER DomainName
    FQDN of the AD domain (e.g., bjdazure.tech)

.PARAMETER DomainNetbios
    NetBIOS name for the domain (e.g., BJDAZURE)

.PARAMETER SafeModePassword
    Directory Services Restore Mode (DSRM) password.

.PARAMETER AdminUsername
    Local admin username (becomes the domain admin).

.PARAMETER AdminPassword
    Password for the admin account.

.NOTES
    Executed by Azure Custom Script Extension during DC provisioning.
    The VM will reboot automatically after promotion.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DomainName,

    [Parameter(Mandatory = $true)]
    [string]$DomainNetbios,

    [Parameter(Mandatory = $true)]
    [string]$SafeModePassword,

    [Parameter(Mandatory = $true)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $true)]
    [string]$AdminPassword
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\setup-domain-controller.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Output $Message
}

# ============================================================
# 1. Install AD DS and DNS roles
# ============================================================
Write-Log "Installing AD DS and DNS roles..."

Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
Write-Log "AD DS and DNS features installed"

# ============================================================
# 2. Promote to Domain Controller (new forest)
# ============================================================
Write-Log "Promoting to Domain Controller for forest: $DomainName"

$securePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force

Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $DomainNetbios `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDns:$true `
    -SafeModeAdministratorPassword $securePassword `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -NoRebootOnCompletion:$false `
    -Force:$true

Write-Log "AD DS promotion initiated -- VM will reboot"
