using System.Collections.Generic;
using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public interface ITenantRepository
    {
        IQueryable<Tenant> Search(int? propertyId, string search);
        Tenant GetWithProperty(int id);
        IList<Tenant> GetByProperty(int propertyId);
        Tenant GetById(int id);
        void Add(Tenant tenant);
        void Update(Tenant tenant);
        int Save();
    }
}
