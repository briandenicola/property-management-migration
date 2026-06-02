using System;
using System.ComponentModel.DataAnnotations;

namespace PropertyManager.Data.Entities
{
    public class MaintenanceStatusHistory
    {
        public int Id { get; set; }
        public int MaintenanceRequestId { get; set; }
        public RequestStatus FromStatus { get; set; }
        public RequestStatus ToStatus { get; set; }

        [MaxLength(128)]
        public string ChangedBy { get; set; }
        public DateTime ChangedOn { get; set; }

        public virtual MaintenanceRequest MaintenanceRequest { get; set; }
    }
}
