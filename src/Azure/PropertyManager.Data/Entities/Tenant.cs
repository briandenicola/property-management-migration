using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace PropertyManager.Data.Entities
{
    public class Tenant
    {
        public Tenant()
        {
            MaintenanceRequests = new HashSet<MaintenanceRequest>();
            IsActive = true;
            CreatedDate = DateTime.Now;
        }

        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string FirstName { get; set; }

        [Required]
        [MaxLength(100)]
        public string LastName { get; set; }

        [Required]
        [MaxLength(256)]
        public string Email { get; set; }

        [MaxLength(20)]
        public string Phone { get; set; }

        [Required]
        [MaxLength(50)]
        public string Unit { get; set; }

        public DateTime LeaseStart { get; set; }
        public DateTime? LeaseEnd { get; set; }
        public int PropertyId { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedDate { get; set; }

        public virtual Property Property { get; set; }
        public virtual ICollection<MaintenanceRequest> MaintenanceRequests { get; set; }
    }
}
