using System;
using System.Data.Entity.Migrations;
using System.Linq;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data.Migrations
{
    public sealed class Configuration : DbMigrationsConfiguration<PropertyManager.Data.PropertyManagerContext>
    {
        public Configuration()
        {
            AutomaticMigrationsEnabled = true;
            AutomaticMigrationDataLossAllowed = true;
            ContextKey = "PropertyManager.Data.PropertyManagerContext";
        }

        protected override void Seed(PropertyManager.Data.PropertyManagerContext context)
        {
            if (context.Properties.Any()) return;

            var props = new[]
            {
                new Property { Name = "Sunset Ridge Apartments", Address = "1200 Sunset Blvd", City = "Austin", State = "TX", ZipCode = "78701", Units = 24, YearBuilt = 1998 },
                new Property { Name = "Oak Park Townhomes", Address = "450 Oak Park Dr", City = "Round Rock", State = "TX", ZipCode = "78664", Units = 12, YearBuilt = 2005 },
                new Property { Name = "Riverside Condos", Address = "88 River Walk Ln", City = "San Antonio", State = "TX", ZipCode = "78205", Units = 36, YearBuilt = 2012 },
                new Property { Name = "Cedar Hills Complex", Address = "3300 Cedar Hills Rd", City = "Dallas", State = "TX", ZipCode = "75201", Units = 48, YearBuilt = 1992 },
                new Property { Name = "Magnolia Flats", Address = "720 Magnolia St", City = "Houston", State = "TX", ZipCode = "77002", Units = 16, YearBuilt = 2018 }
            };
            context.Properties.AddRange(props);
            context.SaveChanges();

            var tenants = new[]
            {
                new Tenant { FirstName = "Sarah", LastName = "Mitchell", Email = "sarah.mitchell@email.com", Phone = "512-555-0101", Unit = "A-101", LeaseStart = new DateTime(2024, 3, 1), PropertyId = props[0].Id },
                new Tenant { FirstName = "James", LastName = "Rodriguez", Email = "j.rodriguez@email.com", Phone = "512-555-0102", Unit = "A-204", LeaseStart = new DateTime(2024, 6, 15), PropertyId = props[0].Id },
                new Tenant { FirstName = "Emily", LastName = "Chen", Email = "emily.chen@email.com", Phone = "512-555-0201", Unit = "B-3", LeaseStart = new DateTime(2023, 9, 1), PropertyId = props[1].Id },
                new Tenant { FirstName = "Marcus", LastName = "Thompson", Email = "m.thompson@email.com", Phone = "210-555-0301", Unit = "C-512", LeaseStart = new DateTime(2024, 1, 1), PropertyId = props[2].Id },
                new Tenant { FirstName = "Aisha", LastName = "Patel", Email = "aisha.patel@email.com", Phone = "210-555-0302", Unit = "C-108", LeaseStart = new DateTime(2024, 8, 1), PropertyId = props[2].Id },
                new Tenant { FirstName = "David", LastName = "Kim", Email = "david.kim@email.com", Phone = "214-555-0401", Unit = "D-302", LeaseStart = new DateTime(2023, 11, 1), PropertyId = props[3].Id },
                new Tenant { FirstName = "Rachel", LastName = "Okonkwo", Email = "r.okonkwo@email.com", Phone = "713-555-0501", Unit = "E-7", LeaseStart = new DateTime(2024, 4, 1), PropertyId = props[4].Id }
            };
            context.Tenants.AddRange(tenants);
            context.SaveChanges();

            var requests = new[]
            {
                new MaintenanceRequest { Title = "Leaking kitchen faucet", Description = "Kitchen faucet drips constantly. Water bill has gone up.", Status = RequestStatus.Open, Priority = RequestPriority.Medium, TenantId = tenants[0].Id, PropertyId = props[0].Id },
                new MaintenanceRequest { Title = "AC not cooling", Description = "Air conditioning unit blows warm air. Thermostat set to 72 but apartment is 85+.", Status = RequestStatus.InProgress, Priority = RequestPriority.High, TenantId = tenants[1].Id, PropertyId = props[0].Id },
                new MaintenanceRequest { Title = "Broken window lock", Description = "Bedroom window lock is broken and window won't stay closed.", Status = RequestStatus.Open, Priority = RequestPriority.High, TenantId = tenants[2].Id, PropertyId = props[1].Id },
                new MaintenanceRequest { Title = "Garbage disposal jammed", Description = "Garbage disposal makes grinding noise and won't turn on.", Status = RequestStatus.Completed, Priority = RequestPriority.Low, TenantId = tenants[3].Id, PropertyId = props[2].Id, CompletedDate = DateTime.Now.AddDays(-3) },
                new MaintenanceRequest { Title = "Water heater failure", Description = "No hot water for 2 days. Water heater making loud banging noises.", Status = RequestStatus.InProgress, Priority = RequestPriority.Emergency, TenantId = tenants[4].Id, PropertyId = props[2].Id },
                new MaintenanceRequest { Title = "Carpet stain in hallway", Description = "Large stain appeared in common hallway carpet. Possibly from roof leak above.", Status = RequestStatus.Open, Priority = RequestPriority.Low, TenantId = tenants[5].Id, PropertyId = props[3].Id }
            };
            context.MaintenanceRequests.AddRange(requests);
            context.SaveChanges();
        }
    }
}
