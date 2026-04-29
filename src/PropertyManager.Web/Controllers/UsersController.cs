using System.Linq;
using System.Web.Http;
using PropertyManager.Data;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [RoutePrefix("api/users")]
    public class UsersController : ApiController
    {
        [HttpGet]
        [Route("")]
        public IHttpActionResult GetAll(bool? isActive = null, string role = null)
        {
            using (var context = new PropertyManagerContext())
            {
                var query = context.Users.AsQueryable();

                if (isActive.HasValue)
                {
                    query = query.Where(u => u.IsActive == isActive.Value);
                }

                if (!string.IsNullOrWhiteSpace(role))
                {
                    query = query.Where(u => u.Role == role);
                }

                var users = query
                    .OrderBy(u => u.LastName)
                    .ThenBy(u => u.FirstName)
                    .Select(u => new UserDto
                    {
                        Id = u.Id,
                        Email = u.Email,
                        FirstName = u.FirstName,
                        LastName = u.LastName,
                        Role = u.Role,
                        IsActive = u.IsActive
                    })
                    .ToList();

                return Ok(users);
            }
        }
    }
}
