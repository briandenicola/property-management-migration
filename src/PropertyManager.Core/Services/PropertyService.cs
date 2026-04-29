using System;
using System.Collections.Generic;
using System.Linq;
using PropertyManager.Core.Interfaces;
using PropertyManager.Data;
using PropertyManager.Data.Entities;
using PropertyManager.Data.Repositories;

namespace PropertyManager.Core.Services
{
    public class PropertyService : IPropertyService
    {
        private readonly PropertyManagerContext _context;
        private readonly IPropertyRepository _propertyRepository;
        private readonly ITenantRepository _tenantRepository;

        public PropertyService(PropertyManagerContext context, IPropertyRepository propertyRepository, ITenantRepository tenantRepository)
        {
            _context = context;
            _propertyRepository = propertyRepository;
            _tenantRepository = tenantRepository;
        }

        public IList<Property> GetAll(string search, bool? isActive)
        {
            return _propertyRepository.Search(search, isActive).ToList();
        }

        public Property GetById(int id)
        {
            return _propertyRepository.GetWithTenants(id);
        }

        public Property Create(Property property)
        {
            property.CreatedDate = DateTime.Now;
            property.IsActive = true;
            _propertyRepository.Add(property);
            _propertyRepository.Save();
            return property;
        }

        public bool Update(int id, Property property)
        {
            var existing = _propertyRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            existing.Name = property.Name;
            existing.Address = property.Address;
            existing.City = property.City;
            existing.State = property.State;
            existing.ZipCode = property.ZipCode;
            existing.Units = property.Units;
            existing.YearBuilt = property.YearBuilt;
            existing.IsActive = property.IsActive;
            existing.ModifiedDate = DateTime.Now;

            _propertyRepository.Update(existing);
            _propertyRepository.Save();
            return true;
        }

        public bool SoftDelete(int id)
        {
            var existing = _propertyRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            existing.IsActive = false;
            existing.ModifiedDate = DateTime.Now;
            _propertyRepository.Update(existing);
            _propertyRepository.Save();
            return true;
        }
    }
}
