using System.Linq;
using System.Web.Http;
using PropertyManager.Core.Interfaces;
using PropertyManager.Data.Entities;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [RoutePrefix("api/properties")]
    public class PropertiesController : ApiController
    {
        private readonly IPropertyService _propertyService;

        public PropertiesController()
        {
            _propertyService = LegacyServiceLocator.GetPropertyService();
        }

        [HttpGet]
        [Route("")]
        public IHttpActionResult GetAll(string search = null, bool? isActive = null)
        {
            var properties = _propertyService.GetAll(search, isActive)
                .Select(MapToDto)
                .ToList();
            return Ok(properties);
        }

        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult GetById(int id)
        {
            var property = _propertyService.GetById(id);
            if (property == null)
            {
                return NotFound();
            }

            return Ok(MapToDto(property));
        }

        [HttpPost]
        [Route("")]
        public IHttpActionResult Create(PropertyDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Property is required.");
            }

            var entity = new Property
            {
                Name = dto.Name,
                Address = dto.Address,
                City = dto.City,
                State = dto.State,
                ZipCode = dto.ZipCode,
                Units = dto.Units,
                YearBuilt = dto.YearBuilt
            };

            var created = _propertyService.Create(entity);
            return Created($"/api/properties/{created.Id}", MapToDto(created));
        }

        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Update(int id, PropertyDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Property is required.");
            }

            var entity = new Property
            {
                Name = dto.Name,
                Address = dto.Address,
                City = dto.City,
                State = dto.State,
                ZipCode = dto.ZipCode,
                Units = dto.Units,
                YearBuilt = dto.YearBuilt,
                IsActive = dto.IsActive
            };

            var updated = _propertyService.Update(id, entity);
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
            var deleted = _propertyService.SoftDelete(id);
            if (!deleted)
            {
                return NotFound();
            }

            return Ok();
        }

        private static PropertyDto MapToDto(Property property)
        {
            return new PropertyDto
            {
                Id = property.Id,
                Name = property.Name,
                Address = property.Address,
                City = property.City,
                State = property.State,
                ZipCode = property.ZipCode,
                Units = property.Units,
                YearBuilt = property.YearBuilt,
                IsActive = property.IsActive,
                CreatedDate = property.CreatedDate,
                TenantCount = property.Tenants != null ? property.Tenants.Count : 0
            };
        }
    }
}
