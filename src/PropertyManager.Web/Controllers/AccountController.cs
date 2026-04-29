using System.Web;
using System.Web.Http;
using Microsoft.AspNet.Identity;
using Microsoft.AspNet.Identity.Owin;
using Microsoft.Owin.Security;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [RoutePrefix("api/account")]
    public class AccountController : ApiController
    {
        [HttpPost]
        [Route("login")]
        [AllowAnonymous]
        public IHttpActionResult Login(LoginRequestDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.Username) || string.IsNullOrWhiteSpace(model.Password))
            {
                return BadRequest("Username and password are required.");
            }

            return Ok(new { message = "Legacy cookie auth endpoint placeholder." });
        }

        [HttpPost]
        [Route("logout")]
        public IHttpActionResult Logout()
        {
            var auth = HttpContext.Current.GetOwinContext().Authentication;
            auth.SignOut(DefaultAuthenticationTypes.ApplicationCookie);
            return Ok();
        }

        [HttpGet]
        [Route("userinfo")]
        public IHttpActionResult UserInfo()
        {
            return Ok(new UserInfoDto
            {
                UserId = User.Identity.GetUserId(),
                UserName = User.Identity.Name,
                IsAuthenticated = User.Identity.IsAuthenticated
            });
        }
    }
}
