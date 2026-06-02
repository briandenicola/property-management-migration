using System;
using System.Collections.Generic;
using System.Linq;
using PropertyManager.Core.Interfaces;
using PropertyManager.Data;
using PropertyManager.Data.Entities;
using PropertyManager.Data.Repositories;

namespace PropertyManager.Core.Services
{
    public class TenantService : ITenantService
    {
        private readonly PropertyManagerContext _context;
        private readonly ITenantRepository _tenantRepository;

        public TenantService(PropertyManagerContext context, ITenantRepository tenantRepository)
        {
            _context = context;
            _tenantRepository = tenantRepository;
        }

        public IList<Tenant> GetAll(int? propertyId, string search)
        {
            return _tenantRepository.Search(propertyId, search).ToList();
        }

        public IList<Tenant> GetByProperty(int propertyId)
        {
            return _tenantRepository.GetByProperty(propertyId);
        }

        public Tenant GetById(int id)
        {
            return _tenantRepository.GetWithProperty(id);
        }

        public Tenant Create(Tenant tenant)
        {
            tenant.CreatedDate = DateTime.Now;
            tenant.IsActive = true;
            _tenantRepository.Add(tenant);
            _tenantRepository.Save();
            return tenant;
        }

        public bool Update(int id, Tenant tenant)
        {
            var existing = _tenantRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            existing.FirstName = tenant.FirstName;
            existing.LastName = tenant.LastName;
            existing.Email = tenant.Email;
            existing.Phone = tenant.Phone;
            existing.Unit = tenant.Unit;
            existing.LeaseStart = tenant.LeaseStart;
            existing.LeaseEnd = tenant.LeaseEnd;
            existing.PropertyId = tenant.PropertyId;
            existing.IsActive = tenant.IsActive;

            _tenantRepository.Update(existing);
            _tenantRepository.Save();
            return true;
        }

        public bool SoftDelete(int id)
        {
            var existing = _tenantRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            existing.IsActive = false;
            _tenantRepository.Update(existing);
            _tenantRepository.Save();
            return true;
        }
    }
}
