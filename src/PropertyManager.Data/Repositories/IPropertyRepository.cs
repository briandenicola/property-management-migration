using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public interface IPropertyRepository
    {
        IQueryable<Property> Search(string search, bool? isActive);
        Property GetWithTenants(int id);
        Property GetById(int id);
        void Add(Property property);
        void Update(Property property);
        int Save();
    }
}
