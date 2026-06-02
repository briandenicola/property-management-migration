using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace PropertyManager.Data.Entities
{
    public class MaintenanceRequest
    {
        public MaintenanceRequest()
        {
            Attachments = new HashSet<Attachment>();
            StatusHistories = new HashSet<MaintenanceStatusHistory>();
            CreatedDate = DateTime.Now;
            Status = RequestStatus.Open;
            Priority = RequestPriority.Medium;
        }

        public int Id { get; set; }

        [Required]
        [MaxLength(200)]
        public string Title { get; set; }

        [Required]
        public string Description { get; set; }

        public RequestStatus Status { get; set; }
        public RequestPriority Priority { get; set; }
        public int TenantId { get; set; }
        public int PropertyId { get; set; }
        [MaxLength(128)]
        public string AssignedToId { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? UpdatedDate { get; set; }
        public DateTime? CompletedDate { get; set; }
        public string Notes { get; set; }

        public virtual Tenant Tenant { get; set; }
        public virtual Property Property { get; set; }
        public virtual ApplicationUser AssignedTo { get; set; }
        public virtual ICollection<Attachment> Attachments { get; set; }
        public virtual ICollection<MaintenanceStatusHistory> StatusHistories { get; set; }
    }
}
