using System;
using System.Collections.Generic;
using PropertyManager.Core.Interfaces;
using PropertyManager.Data;
using PropertyManager.Data.Entities;
using PropertyManager.Data.Repositories;

namespace PropertyManager.Core.Services
{
    public class AttachmentService : IAttachmentService
    {
        private readonly PropertyManagerContext _context;
        private readonly IAttachmentRepository _attachmentRepository;

        public AttachmentService(PropertyManagerContext context, IAttachmentRepository attachmentRepository)
        {
            _context = context;
            _attachmentRepository = attachmentRepository;
        }

        public IList<Attachment> GetByMaintenanceRequestId(int requestId)
        {
            return _attachmentRepository.GetByMaintenanceRequestId(requestId);
        }

        public Attachment GetById(int id)
        {
            return _attachmentRepository.GetById(id);
        }

        public Attachment SaveUpload(int requestId, string fileName, string contentType, byte[] fileData, string uploadedById)
        {
            var attachment = new Attachment
            {
                MaintenanceRequestId = requestId,
                FileName = fileName,
                ContentType = contentType,
                FileData = fileData,
                FileSize = fileData.LongLength,
                UploadedById = uploadedById,
                UploadedDate = DateTime.Now
            };

            _attachmentRepository.Add(attachment);
            _attachmentRepository.Save();
            return attachment;
        }

        public bool Delete(int id)
        {
            var attachment = _attachmentRepository.GetById(id);
            if (attachment == null)
            {
                return false;
            }

            _attachmentRepository.Delete(attachment);
            _attachmentRepository.Save();
            return true;
        }
    }
}
