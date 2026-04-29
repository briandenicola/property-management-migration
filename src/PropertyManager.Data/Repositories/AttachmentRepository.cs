using System.Collections.Generic;
using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public class AttachmentRepository : GenericRepository<Attachment>, IAttachmentRepository
    {
        public AttachmentRepository(PropertyManagerContext context) : base(context)
        {
        }

        public IList<Attachment> GetByMaintenanceRequestId(int maintenanceRequestId)
        {
            return Query()
                .Where(a => a.MaintenanceRequestId == maintenanceRequestId)
                .OrderByDescending(a => a.UploadedDate)
                .ToList();
        }

        public new Attachment GetById(int id)
        {
            return base.GetById(id);
        }
    }
}
