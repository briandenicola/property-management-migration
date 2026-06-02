<#
.SYNOPSIS
    Creates AD organizational units, groups, and demo users for PropertyManager.
    Run this AFTER the DC has rebooted and AD DS is fully operational.

.PARAMETER DomainName
    FQDN of the AD domain (e.g., bjdazure.tech)

.NOTES
    This script should be run manually or via a second extension after DC reboot.
    It creates the OUs, security groups, and test users needed for the demo.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DomainName
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\configure-ad-objects.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Output $Message
}

Import-Module ActiveDirectory

$domainDN = ($DomainName.Split('.') | ForEach-Object { "DC=$_" }) -join ','

# ============================================================
# 1. Create Organizational Units
# ============================================================
Write-Log "Creating Organizational Units..."

$ous = @(
    @{ Name = "PropertyManager"; Path = $domainDN },
    @{ Name = "Users";  Path = "OU=PropertyManager,$domainDN" },
    @{ Name = "Groups"; Path = "OU=PropertyManager,$domainDN" }
)

foreach ($ou in $ous) {
    $ouDN = "OU=$($ou.Name),$($ou.Path)"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ProtectedFromAccidentalDeletion $false
        Write-Log "  Created OU: $ouDN"
    } else {
        Write-Log "  OU already exists: $ouDN"
    }
}

# ============================================================
# 2. Create Security Groups
# ============================================================
Write-Log "Creating Security Groups..."

$groupsOU = "OU=Groups,OU=PropertyManager,$domainDN"
$groups = @(
    @{ Name = "PropertyManager-Admins"; Description = "Property Manager application administrators" },
    @{ Name = "PropertyManager-Users";  Description = "Property Manager standard users" }
)

foreach ($group in $groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $group.Name `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $groupsOU `
            -Description $group.Description
        Write-Log "  Created group: $($group.Name)"
    } else {
        Write-Log "  Group already exists: $($group.Name)"
    }
}

# ============================================================
# 3. Create Demo Users
# ============================================================
Write-Log "Creating demo users..."

$usersOU = "OU=Users,OU=PropertyManager,$domainDN"
$defaultPassword = ConvertTo-SecureString "P@ssw0rd2024!" -AsPlainText -Force

$users = @(
    @{ First = "Alice";   Last = "Manager";    SAM = "alice.manager";    Group = "PropertyManager-Admins" },
    @{ First = "Bob";     Last = "Admin";      SAM = "bob.admin";       Group = "PropertyManager-Admins" },
    @{ First = "Charlie"; Last = "Tenant";     SAM = "charlie.tenant";  Group = "PropertyManager-Users"  },
    @{ First = "Diana";   Last = "Resident";   SAM = "diana.resident";  Group = "PropertyManager-Users"  },
    @{ First = "Eve";     Last = "Maintenance"; SAM = "eve.maintenance"; Group = "PropertyManager-Users"  }
)

foreach ($user in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.SAM)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name "$($user.First) $($user.Last)" `
            -GivenName $user.First `
            -Surname $user.Last `
            -SamAccountName $user.SAM `
            -UserPrincipalName "$($user.SAM)@$DomainName" `
            -Path $usersOU `
            -AccountPassword $defaultPassword `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -ChangePasswordAtLogon $false

        Add-ADGroupMember -Identity $user.Group -Members $user.SAM
        Write-Log "  Created user: $($user.SAM) -> $($user.Group)"
    } else {
        Write-Log "  User already exists: $($user.SAM)"
    }
}

# ============================================================
# 4. Summary
# ============================================================
Write-Log "=========================================="
Write-Log "AD configuration complete!"
Write-Log "  Domain: $DomainName"
Write-Log "  OUs: PropertyManager/Users, PropertyManager/Groups"
Write-Log "  Admin Group: PropertyManager-Admins (alice.manager, bob.admin)"
Write-Log "  User Group:  PropertyManager-Users (charlie.tenant, diana.resident, eve.maintenance)"
Write-Log "  Default password: P@ssw0rd2024!"
Write-Log "=========================================="
