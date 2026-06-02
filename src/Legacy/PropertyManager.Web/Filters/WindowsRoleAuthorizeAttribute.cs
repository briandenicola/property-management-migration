using System.Configuration;
using System.Linq;
using System.Security.Principal;
using System.Web.Http;
using System.Web.Http.Controllers;

namespace PropertyManager.Web.Filters
{
    public class WindowsRoleAuthorizeAttribute : AuthorizeAttribute
    {
        public string AppRoles { get; set; }

        protected override bool IsAuthorized(HttpActionContext actionContext)
        {
            var principal = actionContext.RequestContext.Principal;
            if (principal == null || principal.Identity == null || !principal.Identity.IsAuthenticated)
            {
                return false;
            }

            if (string.IsNullOrWhiteSpace(AppRoles))
            {
                return true;
            }

            var identity = principal.Identity as WindowsIdentity;
            if (identity == null)
            {
                return false;
            }

            var windowsPrincipal = principal as WindowsPrincipal ?? new WindowsPrincipal(identity);
            var requiredRoles = AppRoles.Split(',').Select(r => r.Trim());
            var userRole = ResolveRole(windowsPrincipal);

            return requiredRoles.Contains(userRole);
        }

        private static string ResolveRole(WindowsPrincipal principal)
        {
            var adminGroups = (ConfigurationManager.AppSettings["Auth:AdminGroups"] ?? "BUILTIN\\Administrators")
                .Split(',')
                .Select(g => g.Trim())
                .Where(g => !string.IsNullOrEmpty(g));

            foreach (var group in adminGroups)
            {
                if (principal.IsInRole(group))
                {
                    return "Admin";
                }
            }

            var userGroups = (ConfigurationManager.AppSettings["Auth:UserGroups"] ?? "BUILTIN\\Users")
                .Split(',')
                .Select(g => g.Trim())
                .Where(g => !string.IsNullOrEmpty(g));

            foreach (var group in userGroups)
            {
                if (principal.IsInRole(group))
                {
                    return "User";
                }
            }

            return "User";
        }
    }
}
