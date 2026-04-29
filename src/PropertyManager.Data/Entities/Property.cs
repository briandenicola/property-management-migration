using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace PropertyManager.Data.Entities
{
    public class Property
    {
        public Property()
        {
            Tenants = new HashSet<Tenant>();
            MaintenanceRequests = new HashSet<MaintenanceRequest>();
            IsActive = true;
            CreatedDate = DateTime.Now;
        }

        public int Id { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; }

        [Required]
        [MaxLength(500)]
        public string Address { get; set; }

        [Required]
        [MaxLength(100)]
        public string City { get; set; }

        [Required]
        [MaxLength(2)]
        public string State { get; set; }

        [Required]
        [MaxLength(10)]
        public string ZipCode { get; set; }

        public int Units { get; set; }
        public int? YearBuilt { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? ModifiedDate { get; set; }

        public virtual ICollection<Tenant> Tenants { get; set; }
        public virtual ICollection<MaintenanceRequest> MaintenanceRequests { get; set; }
    }
}
