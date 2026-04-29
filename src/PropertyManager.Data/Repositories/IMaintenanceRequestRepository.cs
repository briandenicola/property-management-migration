using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public interface IMaintenanceRequestRepository
    {
        IQueryable<MaintenanceRequest> Search(int? status, int? propertyId, int? tenantId, int? priority);
        MaintenanceRequest GetWithDetails(int id);
        MaintenanceRequest GetById(int id);
        void Add(MaintenanceRequest request);
        void Update(MaintenanceRequest request);
        void Delete(MaintenanceRequest request);
        int Save();
    }
}
