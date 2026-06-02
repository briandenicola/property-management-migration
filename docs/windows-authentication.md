# Windows Authentication — PropertyManager Legacy App

## Overview

PropertyManager now uses **IIS Windows Authentication** for both the Web API and the AngularJS SPA. Users do not sign in with an application-specific login form. Instead, the browser sends the current Windows credentials to IIS, IIS authenticates the request, and Web API reads the Windows identity from `User.Identity`.

Key points:
- Authentication is handled by **IIS integrated Windows auth**, not OWIN or ASP.NET Identity cookies.
- Authorization is based on **Active Directory / Windows group membership**.
- The app maps Windows groups to two application roles: **Admin** and **User**.
- ASP.NET Identity tables remain in the database for legacy user data, but they are **not** the authentication source.

## Request Flow

1. Browser requests the SPA or an API endpoint.
2. IIS challenges the browser using Windows Authentication.
3. Browser automatically sends the user's domain credentials.
4. IIS sets the authenticated `WindowsIdentity` on the request.
5. Web API controllers use `[Authorize]` for authenticated access.
6. Admin-only endpoints use `WindowsRoleAuthorizeAttribute`, which maps Windows groups to app roles.
7. The SPA loads `/api/account/userinfo` on startup to display the current user and role.

## Configuration

### web.config

`src/PropertyManager.Web\web.config` enables Windows Authentication and disables anonymous access:

```xml
<system.web>
  <authentication mode="Windows" />
  <authorization>
    <deny users="?" />
  </authorization>
</system.web>

<system.webServer>
  <security>
    <authentication>
      <windowsAuthentication enabled="true" />
      <anonymousAuthentication enabled="false" />
    </authentication>
  </security>
</system.webServer>
```

### Group-to-role mapping

Application roles are configured through `appSettings`:

```xml
<add key="Auth:AdminGroups" value="DOMAIN\PropertyManager-Admins,BUILTIN\Administrators" />
<add key="Auth:UserGroups" value="DOMAIN\PropertyManager-Users,BUILTIN\Users" />
```

Rules:
- If the user is in any `Auth:AdminGroups` entry, the app role is **Admin**.
- Otherwise the user is treated as **User**.
- `Auth:UserGroups` is still evaluated and documented so production IIS / AD admins have an explicit place to record the standard user groups.

Use **fully qualified group names** exactly as Windows resolves them, for example:
- `CONTOSO\PropertyManager-Admins`
- `CONTOSO\PropertyManager-Users`
- `BUILTIN\Administrators`
- `BUILTIN\Users`

## IIS Setup

### Required IIS authentication settings

For the PropertyManager site or application:
1. Open **IIS Manager**.
2. Select the site or application.
3. Open **Authentication**.
4. Set **Windows Authentication = Enabled**.
5. Set **Anonymous Authentication = Disabled**.
6. Recycle the app pool after changing authentication settings.

Equivalent PowerShell:

```powershell
Import-Module WebAdministration

Set-WebConfigurationProperty -PSPath 'IIS:\' -Location 'Default Web Site/PropertyPro' -Filter "system.webServer/security/authentication/windowsAuthentication" -Name enabled -Value true
Set-WebConfigurationProperty -PSPath 'IIS:\' -Location 'Default Web Site/PropertyPro' -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Value false
```

### Browser considerations

Windows Authentication is transparent only when the browser trusts the site for integrated auth.

- **Edge / Chrome:** add the site to the Local Intranet zone if credentials are not sent automatically.
- **Firefox:** configure `network.automatic-ntlm-auth.trusted-uris` if Firefox is used internally.
- If users keep seeing a credential prompt, verify the URL, zone assignment, and SPN / host configuration.

## AD Group Setup

Recommended groups:
- `DOMAIN\PropertyManager-Admins`
- `DOMAIN\PropertyManager-Users`

Recommended process:
1. Create dedicated AD security groups for the app.
2. Add property managers / IT admins to the admin group.
3. Add general staff to the user group.
4. Update `web.config` appSettings for the deployed environment.
5. Recycle the app pool or restart the site.
6. Validate by browsing to `/api/account/userinfo` as both an admin and a standard user.

## API behavior

### AccountController

`GET /api/account/userinfo` returns:
- `userId`
- `userName`
- `displayName`
- `role`
- `isAuthenticated`

Example response:

```json
{
  "userId": "S-1-5-21-...",
  "userName": "CONTOSO\\jdoe",
  "displayName": "jdoe",
  "role": "Admin",
  "isAuthenticated": true
}
```

### Authorization model

- `[Authorize]` = any authenticated Windows user
- `[WindowsRoleAuthorize(AppRoles = "Admin")]` = authenticated Windows user in an admin-mapped group

## Role-based access matrix

| Resource | GET (List/Detail) | POST (Create) | PUT (Update) | DELETE |
|---|---|---|---|---|
| Properties | All authenticated | Admin only | Admin only | Admin only |
| Tenants | All authenticated | Admin only | Admin only | Admin only |
| Maintenance Requests | All authenticated | All authenticated | All authenticated | Admin only |
| Attachments | All authenticated | All authenticated | N/A | Admin only |
| Users | Admin only | N/A | N/A | N/A |
| Account/UserInfo | All authenticated | N/A | N/A | N/A |

Additional admin-only action:
- Maintenance request assignment (`PUT /api/maintenancerequests/{id}/assign`) is **Admin only**.

## Troubleshooting

### 401 Unauthorized immediately on every request
- Confirm **Windows Authentication** is enabled in IIS.
- Confirm **Anonymous Authentication** is disabled.
- Confirm the browser is sending integrated credentials.
- Confirm `web.config` changes are present in the deployed site.

### Browser shows a login prompt repeatedly
- Verify the site is in the browser's Local Intranet / trusted auth list.
- Verify the hostname resolves to the expected IIS server.
- Check whether a proxy or load balancer is stripping negotiate / NTLM headers.

### User is authenticated but not treated as Admin
- Verify the exact group name in `Auth:AdminGroups`.
- Verify nested group membership is resolvable by Windows on the IIS server.
- Test with `whoami /groups` from a session for that user.
- Recycle IIS after changing group mappings.

### `/api/account/userinfo` works but UI does not show the user
- Open browser dev tools and confirm the `/api/account/userinfo` response.
- Confirm the SPA and API are served from the same origin.
- If you later split origins, Windows auth requests will require credentialed CORS handling.

## Relationship to the Entra ID migration

This Windows Authentication implementation is the **legacy-state identity model**. It keeps the on-prem IIS deployment realistic while preserving a clean separation between:
- **authentication source** (IIS + AD today)
- **application roles** (Admin/User)
- **API authorization rules**

That separation is the bridge to the next migration step:
- Windows / AD group membership can later be replaced with **Microsoft Entra ID** group or app-role claims.
- `/api/account/userinfo` can keep the same contract for the SPA.
- The custom role-resolution logic can be swapped from Windows group checks to Entra claim checks with minimal frontend impact.

In short: this change restores realistic on-prem enterprise auth today and sets up a cleaner path for Entra ID tomorrow.
