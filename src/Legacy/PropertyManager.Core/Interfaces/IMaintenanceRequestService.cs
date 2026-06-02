using System.Collections.Generic;
using PropertyManager.Data.Entities;

namespace PropertyManager.Core.Interfaces
{
    public interface IMaintenanceRequestService
    {
        IList<MaintenanceRequest> GetAll(int? status, int? propertyId, int? tenantId, int? priority);
        MaintenanceRequest GetById(int id);
        MaintenanceRequest Create(MaintenanceRequest request);
        bool Update(int id, MaintenanceRequest request);
        bool UpdateStatus(int id, RequestStatus status);
        bool Assign(int id, string assignedToId);
        bool Delete(int id);
    }
}
