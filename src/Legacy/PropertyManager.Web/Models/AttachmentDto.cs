using System;

namespace PropertyManager.Web.Models
{
    public class AttachmentDto
    {
        public int Id { get; set; }
        public string FileName { get; set; }
        public string ContentType { get; set; }
        public long FileSize { get; set; }
        public int MaintenanceRequestId { get; set; }
        public DateTime UploadedDate { get; set; }
        public string UploadedById { get; set; }
    }
}
