using System;
using System.Collections.Generic;

namespace PropertyManager.Web.Models
{
    public class MaintenanceRequestDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public int Status { get; set; }
        public string StatusName { get; set; }
        public int Priority { get; set; }
        public string PriorityName { get; set; }
        public int TenantId { get; set; }
        public string TenantName { get; set; }
        public int PropertyId { get; set; }
        public string PropertyName { get; set; }
        public string AssignedToId { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? UpdatedDate { get; set; }
        public DateTime? CompletedDate { get; set; }
        public string Notes { get; set; }
        public IList<AttachmentDto> Attachments { get; set; }
    }
}
