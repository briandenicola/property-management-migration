using System.Data.Entity;
using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public class MaintenanceRequestRepository : GenericRepository<MaintenanceRequest>, IMaintenanceRequestRepository
    {
        public MaintenanceRequestRepository(PropertyManagerContext context) : base(context)
        {
        }

        public IQueryable<MaintenanceRequest> Search(int? status, int? propertyId, int? tenantId, int? priority)
        {
            var query = Query()
                .Include(m => m.Tenant)
                .Include(m => m.Property)
                .Include(m => m.Attachments)
                .AsQueryable();

            if (status.HasValue)
            {
                query = query.Where(m => (int)m.Status == status.Value);
            }

            if (propertyId.HasValue)
            {
                query = query.Where(m => m.PropertyId == propertyId.Value);
            }

            if (tenantId.HasValue)
            {
                query = query.Where(m => m.TenantId == tenantId.Value);
            }

            if (priority.HasValue)
            {
                query = query.Where(m => (int)m.Priority == priority.Value);
            }

            return query.OrderByDescending(m => m.CreatedDate);
        }

        public MaintenanceRequest GetWithDetails(int id)
        {
            return Query()
                .Include(m => m.Property)
                .Include(m => m.Tenant)
                .Include(m => m.Attachments)
                .Include(m => m.StatusHistories)
                .FirstOrDefault(m => m.Id == id);
        }

        public new MaintenanceRequest GetById(int id)
        {
            return base.GetById(id);
        }
    }
}
