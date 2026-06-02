using System;
using System.ComponentModel.DataAnnotations;

namespace PropertyManager.Data.Entities
{
    public class Attachment
    {
        public Attachment()
        {
            UploadedDate = DateTime.Now;
        }

        public int Id { get; set; }

        [Required]
        [MaxLength(256)]
        public string FileName { get; set; }

        [Required]
        [MaxLength(100)]
        public string ContentType { get; set; }

        public long FileSize { get; set; }

        [Required]
        public byte[] FileData { get; set; }

        public int MaintenanceRequestId { get; set; }
        public DateTime UploadedDate { get; set; }
        [MaxLength(128)]
        public string UploadedById { get; set; }

        public virtual MaintenanceRequest MaintenanceRequest { get; set; }
        public virtual ApplicationUser UploadedBy { get; set; }
    }
}
