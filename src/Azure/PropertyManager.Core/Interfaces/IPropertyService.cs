using System.Collections.Generic;
using PropertyManager.Data.Entities;

namespace PropertyManager.Core.Interfaces
{
    public interface IPropertyService
    {
        IList<Property> GetAll(string search, bool? isActive);
        Property GetById(int id);
        Property Create(Property property);
        bool Update(int id, Property property);
        bool SoftDelete(int id);
    }
}
