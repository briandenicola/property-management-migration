using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Http;
using Newtonsoft.Json;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [Authorize]
    [RoutePrefix("api/account")]
    public class AccountController : ApiController
    {
        [HttpGet]
        [Route("userinfo")]
        [AllowAnonymous]
        public IHttpActionResult GetUserInfo()
        {
            var principal = GetClientPrincipal();
            if (principal == null)
            {
                return Unauthorized();
            }

            var claims = principal.Claims ?? new List<ClientPrincipalClaim>();

            var dto = new UserInfoDto
            {
                UserId = GetClaimValue(claims, "http://schemas.microsoft.com/identity/claims/objectidentifier") ?? string.Empty,
                UserName = GetClaimValue(claims, "preferred_username")
                    ?? GetClaimValue(claims, "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress")
                    ?? GetClaimValue(claims, "name")
                    ?? string.Empty,
                DisplayName = GetClaimValue(claims, "name") ?? string.Empty,
                Role = GetRole(claims),
                IsAuthenticated = true
            };

            return Ok(dto);
        }

        private ClientPrincipal GetClientPrincipal()
        {
            var header = HttpContext.Current?.Request?.Headers["X-MS-CLIENT-PRINCIPAL"];
            if (string.IsNullOrEmpty(header))
            {
                return null;
            }

            try
            {
                var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(header));
                return JsonConvert.DeserializeObject<ClientPrincipal>(decoded);
            }
            catch
            {
                return null;
            }
        }

        private static string GetClaimValue(List<ClientPrincipalClaim> claims, string type)
        {
            return claims.FirstOrDefault(c => c.Type == type)?.Value;
        }

        private static string GetRole(List<ClientPrincipalClaim> claims)
        {
            var roles = claims
                .Where(c => c.Type == "roles" || c.Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/role")
                .Select(c => c.Value)
                .ToList();

            if (roles.Contains("Admin"))
            {
                return "Admin";
            }

            return "User";
        }

        private class ClientPrincipal
        {
            [JsonProperty("auth_typ")]
            public string AuthType { get; set; }

            [JsonProperty("name_typ")]
            public string NameType { get; set; }

            [JsonProperty("role_typ")]
            public string RoleType { get; set; }

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
