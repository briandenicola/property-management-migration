using System;

namespace PropertyManager.Web.Models
{
    public class PropertyDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Address { get; set; }
        public string City { get; set; }
        public string State { get; set; }
        public string ZipCode { get; set; }
        public int Units { get; set; }
        public int? YearBuilt { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedDate { get; set; }
        public int TenantCount { get; set; }
    }
}
