using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public class TenantRepository : GenericRepository<Tenant>, ITenantRepository
    {
        public TenantRepository(PropertyManagerContext context) : base(context)
        {
        }

        public IQueryable<Tenant> Search(int? propertyId, string search)
        {
            var query = Query().Include(t => t.Property).Where(t => t.IsActive);

            if (propertyId.HasValue)
            {
                query = query.Where(t => t.PropertyId == propertyId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                query = query.Where(t => t.FirstName.Contains(search) || t.LastName.Contains(search) || t.Email.Contains(search));
            }

            return query.OrderBy(t => t.LastName).ThenBy(t => t.FirstName);
        }

        public Tenant GetWithProperty(int id)
        {
            return Query().Include(t => t.Property).FirstOrDefault(t => t.Id == id);
        }

        public IList<Tenant> GetByProperty(int propertyId)
        {
            return Search(propertyId, null).ToList();
        }

        public new Tenant GetById(int id)
        {
            return base.GetById(id);
        }
    }
}
