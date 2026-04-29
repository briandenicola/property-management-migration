using System.Data.Entity;
using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public class PropertyRepository : GenericRepository<Property>, IPropertyRepository
    {
        public PropertyRepository(PropertyManagerContext context) : base(context)
        {
        }

        public IQueryable<Property> Search(string search, bool? isActive)
        {
            var query = Query();

            if (!string.IsNullOrWhiteSpace(search))
            {
                query = query.Where(p => p.Name.Contains(search) || p.Address.Contains(search) || p.City.Contains(search));
            }

            if (isActive.HasValue)
            {
                query = query.Where(p => p.IsActive == isActive.Value);
            }

            return query.OrderBy(p => p.Name);
        }

        public Property GetWithTenants(int id)
        {
            return Query().Include(p => p.Tenants).FirstOrDefault(p => p.Id == id);
        }

        public new Property GetById(int id)
        {
            return base.GetById(id);
        }
    }
}
