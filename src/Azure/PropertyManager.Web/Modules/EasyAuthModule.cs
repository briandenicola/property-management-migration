using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Web;
using Newtonsoft.Json;

namespace PropertyManager.Web.Modules
{
    /// <summary>
    /// HTTP module that reads Azure App Service Easy Auth headers and sets
    /// the thread/request principal so standard [Authorize] attributes work.
    /// </summary>
    public class EasyAuthModule : IHttpModule
    {
        public void Init(HttpApplication context)
        {
            context.AuthenticateRequest += OnAuthenticateRequest;
        }

        private void OnAuthenticateRequest(object sender, EventArgs e)
        {
            var app = (HttpApplication)sender;
            var request = app.Context.Request;

            var principalHeader = request.Headers["X-MS-CLIENT-PRINCIPAL"];
            var nameHeader = request.Headers["X-MS-CLIENT-PRINCIPAL-NAME"];

            if (string.IsNullOrEmpty(principalHeader))
                return;

            try
            {
                var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(principalHeader));
                var principal = JsonConvert.DeserializeObject<EasyAuthPrincipal>(decoded);

                var claims = new List<Claim>();

                if (principal?.Claims != null)
                {
                    foreach (var c in principal.Claims)
                    {
                        // Map "roles" to the standard Role claim type
                        var claimType = c.Type == "roles"
                            ? ClaimTypes.Role
                            : c.Type;
                        claims.Add(new Claim(claimType, c.Value));
                    }
                }

                if (!string.IsNullOrEmpty(nameHeader) && !claims.Any(c => c.Type == ClaimTypes.Name))
                {
                    claims.Add(new Claim(ClaimTypes.Name, nameHeader));
                }

                var identity = new ClaimsIdentity(claims, "EasyAuth", ClaimTypes.Name, ClaimTypes.Role);
                var claimsPrincipal = new ClaimsPrincipal(identity);

                app.Context.User = claimsPrincipal;
                Thread.CurrentPrincipal = claimsPrincipal;
            }
            catch
            {
                // If we can't parse the header, leave the principal unset
            }
        }

        public void Dispose() { }

        private class EasyAuthPrincipal
        {
            [JsonProperty("claims")]
            public List<EasyAuthClaim> Claims { get; set; }
        }

        private class EasyAuthClaim
        {
            [JsonProperty("typ")]
            public string Type { get; set; }

            [JsonProperty("val")]
            public string Value { get; set; }
        }
    }
}
