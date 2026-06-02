using System.Configuration;
using System.Linq;
using System.Security.Principal;
using System.Web.Http;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [Authorize]
    [RoutePrefix("api/account")]
    public class AccountController : ApiController
    {
        [HttpGet]
        [Route("userinfo")]
        public IHttpActionResult GetUserInfo()
        {
            var identity = User.Identity as WindowsIdentity;
            if (identity == null || !identity.IsAuthenticated)
            {
                return Unauthorized();
            }

            var principal = User as WindowsPrincipal ?? new WindowsPrincipal(identity);
            var displayName = identity.Name.Contains("\\")
                ? identity.Name.Split('\\').Last()
                : identity.Name;

            var dto = new UserInfoDto
            {
                UserId = identity.User == null ? identity.Name : identity.User.Value,
                UserName = identity.Name,
                DisplayName = displayName,
                Role = ResolveRole(principal),
                IsAuthenticated = true
            };

            return Ok(dto);
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
