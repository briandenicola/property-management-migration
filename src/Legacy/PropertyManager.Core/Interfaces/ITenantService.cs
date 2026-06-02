using System.Collections.Generic;
using PropertyManager.Data.Entities;

namespace PropertyManager.Core.Interfaces
{
    public interface ITenantService
    {
        IList<Tenant> GetAll(int? propertyId, string search);
        IList<Tenant> GetByProperty(int propertyId);
        Tenant GetById(int id);
        Tenant Create(Tenant tenant);
        bool Update(int id, Tenant tenant);
        bool SoftDelete(int id);
    }
}
