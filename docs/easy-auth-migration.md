# Azure App Service Easy Auth migration for PropertyPro

## Overview

PropertyPro currently authenticates users with IIS Windows Authentication and maps on-premises Active Directory groups to application roles. For Azure App Service, that model is replaced with App Service Easy Auth backed by Microsoft Entra ID. Easy Auth handles sign-in before requests reach the application, and the application reads the authenticated user from the `X-MS-CLIENT-PRINCIPAL` header.

This migration adds:

- Terraform resources for a Microsoft Entra application, service principal, client secret, and app roles.
- App Service `auth_settings_v2` configuration so Azure App Service enforces authentication.
- Azure-specific controller and authorization attribute examples under `src/PropertyManager.Web.Azure\` for documentation and comparison.
- An Azure deployment `web.config` variant that removes IIS Windows Authentication settings.

## Authentication flow changes

| Area | Legacy Windows Auth | Azure Easy Auth |
| --- | --- | --- |
| Sign-in | IIS Windows Authentication | App Service Easy Auth with Entra ID |
| Identity source in code | `WindowsIdentity` / `WindowsPrincipal` | `X-MS-CLIENT-PRINCIPAL` header |
| Role source | AD group membership from config | Entra app roles in token claims |
| Config keys | `Auth:AdminGroups`, `Auth:UserGroups` | App roles assigned in Entra ID |

## Side-by-side code comparison

### Account controller

| Windows Auth | Easy Auth |
| --- | --- |
| `var identity = User.Identity as WindowsIdentity;` | `var header = HttpContext.Current?.Request?.Headers["X-MS-CLIENT-PRINCIPAL"];` |
| `var principal = User as WindowsPrincipal ?? new WindowsPrincipal(identity);` | `var principal = JsonConvert.DeserializeObject<ClientPrincipal>(decoded);` |
| `UserId = identity.User == null ? identity.Name : identity.User.Value` | `UserId = GetClaimValue(claims, "http://schemas.microsoft.com/identity/claims/objectidentifier")` |
| `UserName = identity.Name` | `UserName = preferred_username ?? emailaddress ?? name` |
| `Role = ResolveRole(principal)` | `Role = GetRole(claims)` |

**Windows Auth (`src/PropertyManager.Web\Controllers\AccountController.cs`)**

- Reads `User.Identity` as `WindowsIdentity`
- Builds display name from `DOMAIN\username`
- Resolves `Admin` and `User` from configured AD groups

**Easy Auth (`src/PropertyManager.Web.Azure\Controllers\AccountController.cs`)**

- Reads `X-MS-CLIENT-PRINCIPAL`
- Base64 decodes and deserializes the Easy Auth principal JSON payload
- Extracts:
  - `name` for display name
  - `preferred_username` or `emailaddress` for username
  - `objectidentifier` for user ID
  - `roles` / role claim for app role
- Returns the same `UserInfoDto` shape used by the existing frontend

### Authorization attribute

| Windows Auth | Easy Auth |
| --- | --- |
| `principal.Identity is WindowsIdentity` | `X-MS-CLIENT-PRINCIPAL` header must exist |
| `ResolveRole(windowsPrincipal)` | `userRoles = claims.Where(...roles...)` |
| AD groups from `Auth:AdminGroups` / `Auth:UserGroups` | Entra app roles from token claims |
| `requiredRoles.Contains(userRole)` | `requiredRoles.Any(r => userRoles.Contains(r))` |

**Windows Auth (`src/PropertyManager.Web\Filters\WindowsRoleAuthorizeAttribute.cs`)**

- Checks whether the current principal is authenticated
- Resolves a single app role by evaluating configured AD groups
- Compares the resolved role to `AppRoles`

**Easy Auth (`src/PropertyManager.Web.Azure\Filters\EasyAuthRoleAuthorizeAttribute.cs`)**

- Requires the Easy Auth principal header to exist
- Deserializes claims from the header
- Reads `roles` claims emitted by Entra ID app role assignments
- Grants access when any required role matches the token roles

## Terraform resources added

The Azure infrastructure now includes:

- `azuread` provider in `infrastructure/azure\providers.tf`
- `data.azuread_client_config.current` to read the tenant ID
- `azuread_application.this` with:
  - single-tenant sign-in (`AzureADMyOrg`)
  - `Admin` and `User` app roles
  - Easy Auth callback redirect URI
  - optional `email` and `groups` ID token claims
- `azuread_service_principal.this`
- `azuread_application_password.this` for the Easy Auth client secret
- `random_uuid` resources for stable app role IDs
- `auth_settings_v2` on `azurerm_windows_web_app.this`
- App setting `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET`
- Outputs for the Entra client ID and tenant ID

## Assigning app roles in Azure Portal

1. Deploy the Terraform changes.
2. Open **Microsoft Entra ID** in the Azure Portal.
3. Go to **Enterprise applications**.
4. Open the service principal created for the PropertyPro app registration.
5. Go to **Users and groups**.
6. Select **Add user/group**.
7. Pick the target user or group.
8. Choose either the **Admin** or **User** app role.
9. Save the assignment.

After assignment, the selected role appears in the authenticated user's token as a `roles` claim, which Easy Auth forwards to the application.

## Local testing

Easy Auth only runs inside Azure App Service, so `X-MS-CLIENT-PRINCIPAL` is not populated during normal local IIS Express or Visual Studio runs.

For local testing:

- Continue using the legacy project locally if you need Windows Authentication behavior.
- Treat `src/PropertyManager.Web.Azure\` as reference code for the Azure deployment.
- Deploy to Azure App Service to validate the Easy Auth flow end to end.
- After deployment, call `GET /api/account/userinfo` and verify the returned `UserInfoDto` matches the signed-in user and assigned app role.
