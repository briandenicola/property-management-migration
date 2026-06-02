using System.Collections.Generic;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Repositories
{
    public interface IAttachmentRepository
    {
        IList<Attachment> GetByMaintenanceRequestId(int maintenanceRequestId);
        Attachment GetById(int id);
        void Add(Attachment attachment);
        void Delete(Attachment attachment);
        int Save();
    }
}
