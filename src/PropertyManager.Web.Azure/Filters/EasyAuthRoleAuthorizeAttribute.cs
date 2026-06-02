using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Http;
using System.Web.Http.Controllers;
using Newtonsoft.Json;

namespace PropertyManager.Web.Filters
{
    public class EasyAuthRoleAuthorizeAttribute : AuthorizeAttribute
    {
        public string AppRoles { get; set; }

        protected override bool IsAuthorized(HttpActionContext actionContext)
        {
            var header = HttpContext.Current?.Request?.Headers["X-MS-CLIENT-PRINCIPAL"];
            if (string.IsNullOrEmpty(header))
            {
                return false;
            }

            if (string.IsNullOrWhiteSpace(AppRoles))
            {
                return true;
            }

            try
            {
                var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(header));
                var principal = JsonConvert.DeserializeObject<ClientPrincipal>(decoded);
                var claims = principal?.Claims ?? new List<ClientPrincipalClaim>();

                var userRoles = claims
                    .Where(c => c.Type == "roles" || c.Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/role")
                    .Select(c => c.Value)
                    .ToList();

                var requiredRoles = AppRoles.Split(',').Select(r => r.Trim());
                return requiredRoles.Any(r => userRoles.Contains(r));
            }
            catch
            {
                return false;
            }
        }

        private class ClientPrincipal
        {
            [JsonProperty("claims")]
            public List<ClientPrincipalClaim> Claims { get; set; }
        }

        private class ClientPrincipalClaim
        {
            [JsonProperty("typ")]
            public string Type { get; set; }

            [JsonProperty("val")]
            public string Value { get; set; }
        }
    }
}
