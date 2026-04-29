using System.Collections.Generic;
using PropertyManager.Data.Entities;

namespace PropertyManager.Core.Interfaces
{
    public interface IAttachmentService
    {
        IList<Attachment> GetByMaintenanceRequestId(int requestId);
        Attachment GetById(int id);
        Attachment SaveUpload(int requestId, string fileName, string contentType, byte[] fileData, string uploadedById);
        bool Delete(int id);
    }
}
