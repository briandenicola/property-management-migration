using System;

namespace PropertyManager.Web.Models
{
    public class TenantDto
    {
        public int Id { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Unit { get; set; }
        public DateTime LeaseStart { get; set; }
        public DateTime? LeaseEnd { get; set; }
        public int PropertyId { get; set; }
        public string PropertyName { get; set; }
        public bool IsActive { get; set; }
    }
}
