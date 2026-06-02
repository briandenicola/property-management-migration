using System.Data.Entity;
using Microsoft.AspNet.Identity.EntityFramework;
using PropertyManager.Data.Entities;

namespace PropertyManager.Data
{
    public class PropertyManagerContext : IdentityDbContext<ApplicationUser>
    {
        public PropertyManagerContext() : base("PropertyProDb")
        {
            Configuration.LazyLoadingEnabled = true;
            Configuration.ProxyCreationEnabled = true;
        }

        public virtual DbSet<Property> Properties { get; set; }
        public virtual DbSet<Tenant> Tenants { get; set; }
        public virtual DbSet<MaintenanceRequest> MaintenanceRequests { get; set; }
        public virtual DbSet<Attachment> Attachments { get; set; }
        public virtual DbSet<MaintenanceStatusHistory> MaintenanceStatusHistories { get; set; }

        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Property>().ToTable("Properties");
            modelBuilder.Entity<Tenant>().ToTable("Tenants");
            modelBuilder.Entity<MaintenanceRequest>().ToTable("MaintenanceRequests");
            modelBuilder.Entity<Attachment>().ToTable("Attachments");
            modelBuilder.Entity<MaintenanceStatusHistory>().ToTable("MaintenanceStatusHistories");
            modelBuilder.Entity<ApplicationUser>().ToTable("AspNetUsers");

            modelBuilder.Entity<Attachment>()
                .Property(a => a.FileData)
                .IsRequired();

            modelBuilder.Entity<MaintenanceRequest>()
                .HasMany(m => m.Attachments)
                .WithRequired(a => a.MaintenanceRequest)
                .HasForeignKey(a => a.MaintenanceRequestId)
                .WillCascadeOnDelete(true);

            modelBuilder.Entity<Tenant>()
                .HasMany(t => t.MaintenanceRequests)
                .WithRequired(m => m.Tenant)
                .HasForeignKey(m => m.TenantId)
                .WillCascadeOnDelete(false);

            modelBuilder.Entity<Property>()
                .HasMany(p => p.MaintenanceRequests)
                .WithRequired(m => m.Property)
                .HasForeignKey(m => m.PropertyId)
                .WillCascadeOnDelete(false);

            modelBuilder.Entity<MaintenanceRequest>()
                .HasMany(m => m.StatusHistories)
                .WithRequired(h => h.MaintenanceRequest)
                .HasForeignKey(h => h.MaintenanceRequestId)
                .WillCascadeOnDelete(true);
        }

        public static PropertyManagerContext Create()
        {
            return new PropertyManagerContext();
        }
    }
}
