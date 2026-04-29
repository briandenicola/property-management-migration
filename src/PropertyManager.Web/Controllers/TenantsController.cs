using System.Linq;
using System.Web.Http;
using PropertyManager.Core.Interfaces;
using PropertyManager.Data.Entities;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [RoutePrefix("api/tenants")]
    public class TenantsController : ApiController
    {
        private readonly ITenantService _tenantService;

        public TenantsController()
        {
            _tenantService = LegacyServiceLocator.GetTenantService();
        }

        [HttpGet]
        [Route("")]
        public IHttpActionResult GetAll(int? propertyId = null, string search = null)
        {
            var tenants = _tenantService.GetAll(propertyId, search)
                .Select(MapToDto)
                .ToList();
            return Ok(tenants);
        }

        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult GetById(int id)
        {
            var tenant = _tenantService.GetById(id);
            if (tenant == null)
            {
                return NotFound();
            }

            return Ok(MapToDto(tenant));
        }

        [HttpGet]
        [Route("~/api/properties/{id:int}/tenants")]
        public IHttpActionResult GetByProperty(int id)
        {
            var tenants = _tenantService.GetByProperty(id)
                .Select(MapToDto)
                .ToList();
            return Ok(tenants);
        }

        [HttpPost]
        [Route("")]
        public IHttpActionResult Create(TenantDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Tenant is required.");
            }

            var entity = new Tenant
            {
                FirstName = dto.FirstName,
                LastName = dto.LastName,
                Email = dto.Email,
                Phone = dto.Phone,
                Unit = dto.Unit,
                LeaseStart = dto.LeaseStart,
                LeaseEnd = dto.LeaseEnd,
                PropertyId = dto.PropertyId
            };

            var created = _tenantService.Create(entity);
            return Created($"/api/tenants/{created.Id}", MapToDto(created));
        }

        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Update(int id, TenantDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Tenant is required.");
            }

            var entity = new Tenant
            {
                FirstName = dto.FirstName,
                LastName = dto.LastName,
                Email = dto.Email,
                Phone = dto.Phone,
                Unit = dto.Unit,
                LeaseStart = dto.LeaseStart,
                LeaseEnd = dto.LeaseEnd,
                PropertyId = dto.PropertyId,
                IsActive = dto.IsActive
            };

            var updated = _tenantService.Update(id, entity);
            if (!updated)
            {
                return NotFound();
            }

            return Ok();
        }

        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Delete(int id)
        {
            var deleted = _tenantService.SoftDelete(id);
            if (!deleted)
            {
                return NotFound();
            }

            return Ok();
        }

        private static TenantDto MapToDto(Tenant tenant)
        {
            return new TenantDto
            {
                Id = tenant.Id,
                FirstName = tenant.FirstName,
                LastName = tenant.LastName,
                Email = tenant.Email,
                Phone = tenant.Phone,
                Unit = tenant.Unit,
                LeaseStart = tenant.LeaseStart,
                LeaseEnd = tenant.LeaseEnd,
                PropertyId = tenant.PropertyId,
                PropertyName = tenant.Property != null ? tenant.Property.Name : null,
                IsActive = tenant.IsActive
            };
        }
    }
}
