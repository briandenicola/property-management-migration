using System;
using System.Data.Entity.Migrations;

namespace PropertyManager.Data.Migrations
{
    public partial class InitialCreate : DbMigration
    {
        public override void Up()
        {
            CreateTable(
                "dbo.AspNetUsers",
                c => new
                    {
                        Id = c.String(nullable: false, maxLength: 128),
                        FirstName = c.String(nullable: false, maxLength: 100),
                        LastName = c.String(nullable: false, maxLength: 100),
                        Role = c.String(maxLength: 50),
                        IsActive = c.Boolean(nullable: false),
                        CreatedDate = c.DateTime(nullable: false),
                        Email = c.String(maxLength: 256),
                        EmailConfirmed = c.Boolean(nullable: false),
                        PasswordHash = c.String(),
                        SecurityStamp = c.String(),
                        PhoneNumber = c.String(),
                        PhoneNumberConfirmed = c.Boolean(nullable: false),
                        TwoFactorEnabled = c.Boolean(nullable: false),
                        LockoutEndDateUtc = c.DateTime(),
                        LockoutEnabled = c.Boolean(nullable: false),
                        AccessFailedCount = c.Int(nullable: false),
                        UserName = c.String(nullable: false, maxLength: 256),
                    })
                .PrimaryKey(t => t.Id)
                .Index(t => t.UserName, unique: true, name: "UserNameIndex");

            CreateTable(
                "dbo.AspNetRoles",
                c => new
                    {
                        Id = c.String(nullable: false, maxLength: 128),
                        Name = c.String(nullable: false, maxLength: 256),
                    })
                .PrimaryKey(t => t.Id)
                .Index(t => t.Name, unique: true, name: "RoleNameIndex");

            CreateTable(
                "dbo.AspNetUserRoles",
                c => new
                    {
                        UserId = c.String(nullable: false, maxLength: 128),
                        RoleId = c.String(nullable: false, maxLength: 128),
                    })
                .PrimaryKey(t => new { t.UserId, t.RoleId })
                .ForeignKey("dbo.AspNetRoles", t => t.RoleId, cascadeDelete: true)
                .ForeignKey("dbo.AspNetUsers", t => t.UserId, cascadeDelete: true)
                .Index(t => t.UserId)
                .Index(t => t.RoleId);

            CreateTable(
                "dbo.AspNetUserClaims",
                c => new
                    {
                        Id = c.Int(nullable: false, identity: true),
                        UserId = c.String(nullable: false, maxLength: 128),
                        ClaimType = c.String(),
                        ClaimValue = c.String(),
                    })
                .PrimaryKey(t => t.Id)
                .ForeignKey("dbo.AspNetUsers", t => t.UserId, cascadeDelete: true)
                .Index(t => t.UserId);

            CreateTable(
                "dbo.AspNetUserLogins",
                c => new
                    {
                        LoginProvider = c.String(nullable: false, maxLength: 128),
                        ProviderKey = c.String(nullable: false, maxLength: 128),
                        UserId = c.String(nullable: false, maxLength: 128),
                    })
                .PrimaryKey(t => new { t.LoginProvider, t.ProviderKey, t.UserId })
                .ForeignKey("dbo.AspNetUsers", t => t.UserId, cascadeDelete: true)
                .Index(t => t.UserId);

            CreateTable(
                "dbo.Properties",
                c => new
                    {
                        Id = c.Int(nullable: false, identity: true),
                        Name = c.String(nullable: false, maxLength: 200),
                        Address = c.String(nullable: false, maxLength: 500),
                        City = c.String(nullable: false, maxLength: 100),
                        State = c.String(nullable: false, maxLength: 2),
                        ZipCode = c.String(nullable: false, maxLength: 10),
                        Units = c.Int(nullable: false),
                        YearBuilt = c.Int(),
                        IsActive = c.Boolean(nullable: false),
                        CreatedDate = c.DateTime(nullable: false),
                        ModifiedDate = c.DateTime(),
                    })
                .PrimaryKey(t => t.Id);

            CreateTable(
                "dbo.Tenants",
                c => new
                    {
                        Id = c.Int(nullable: false, identity: true),
                        FirstName = c.String(nullable: false, maxLength: 100),
                        LastName = c.String(nullable: false, maxLength: 100),
                        Email = c.String(nullable: false, maxLength: 256),
                        Phone = c.String(maxLength: 20),
                        Unit = c.String(nullable: false, maxLength: 50),
                        LeaseStart = c.DateTime(nullable: false),
                        LeaseEnd = c.DateTime(),
                        PropertyId = c.Int(nullable: false),
                        IsActive = c.Boolean(nullable: false),
                        CreatedDate = c.DateTime(nullable: false),
                    })
                .PrimaryKey(t => t.Id)
                .ForeignKey("dbo.Properties", t => t.PropertyId)
                .Index(t => t.PropertyId);

            CreateTable(
                "dbo.MaintenanceRequests",
                c => new
                    {
                        Id = c.Int(nullable: false, identity: true),
                        Title = c.String(nullable: false, maxLength: 200),
                        Description = c.String(nullable: false),
                        Status = c.Int(nullable: false),
                        Priority = c.Int(nullable: false),
                        TenantId = c.Int(nullable: false),
                        PropertyId = c.Int(nullable: false),
                        AssignedToId = c.String(maxLength: 128),
                        CreatedDate = c.DateTime(nullable: false),
                        UpdatedDate = c.DateTime(),
                        CompletedDate = c.DateTime(),
                        Notes = c.String(),
                    })
                .PrimaryKey(t => t.Id)
                .ForeignKey("dbo.Properties", t => t.PropertyId)
                .ForeignKey("dbo.Tenants", t => t.TenantId)
                .ForeignKey("dbo.AspNetUsers", t => t.AssignedToId)
                .Index(t => t.TenantId)
                .Index(t => t.PropertyId)
                .Index(t => t.AssignedToId);

            CreateTable(
                "dbo.Attachments",
                c => new
                    {
                        Id = c.Int(nullable: false, identity: true),
                        FileName = c.String(nullable: false, maxLength: 256),
                        ContentType = c.String(nullable: false, maxLength: 100),
                        FileSize = c.Long(nullable: false),
                        FileData = c.Binary(nullable: false),
                        MaintenanceRequestId = c.Int(nullable: false),
                        UploadedDate = c.DateTime(nullable: false),
                        UploadedById = c.String(maxLength: 128),
                    })
                .PrimaryKey(t => t.Id)
                .ForeignKey("dbo.MaintenanceRequests", t => t.MaintenanceRequestId, cascadeDelete: true)
                .ForeignKey("dbo.AspNetUsers", t => t.UploadedById)
                .Index(t => t.MaintenanceRequestId)
                .Index(t => t.UploadedById);
        }

        public override void Down()
        {
            DropForeignKey("dbo.Attachments", "UploadedById", "dbo.AspNetUsers");
            DropForeignKey("dbo.Attachments", "MaintenanceRequestId", "dbo.MaintenanceRequests");
            DropForeignKey("dbo.MaintenanceRequests", "AssignedToId", "dbo.AspNetUsers");
            DropForeignKey("dbo.MaintenanceRequests", "TenantId", "dbo.Tenants");
            DropForeignKey("dbo.MaintenanceRequests", "PropertyId", "dbo.Properties");
            DropForeignKey("dbo.Tenants", "PropertyId", "dbo.Properties");
            DropForeignKey("dbo.AspNetUserLogins", "UserId", "dbo.AspNetUsers");
            DropForeignKey("dbo.AspNetUserClaims", "UserId", "dbo.AspNetUsers");
            DropForeignKey("dbo.AspNetUserRoles", "UserId", "dbo.AspNetUsers");
            DropForeignKey("dbo.AspNetUserRoles", "RoleId", "dbo.AspNetRoles");
            DropIndex("dbo.Attachments", new[] { "UploadedById" });
            DropIndex("dbo.Attachments", new[] { "MaintenanceRequestId" });
            DropIndex("dbo.MaintenanceRequests", new[] { "AssignedToId" });
            DropIndex("dbo.MaintenanceRequests", new[] { "PropertyId" });
            DropIndex("dbo.MaintenanceRequests", new[] { "TenantId" });
            DropIndex("dbo.Tenants", new[] { "PropertyId" });
            DropIndex("dbo.AspNetUserLogins", new[] { "UserId" });
            DropIndex("dbo.AspNetUserClaims", new[] { "UserId" });
            DropIndex("dbo.AspNetUserRoles", new[] { "RoleId" });
            DropIndex("dbo.AspNetUserRoles", new[] { "UserId" });
            DropIndex("dbo.AspNetRoles", "RoleNameIndex");
            DropIndex("dbo.AspNetUsers", "UserNameIndex");
            DropTable("dbo.Attachments");
            DropTable("dbo.MaintenanceRequests");
            DropTable("dbo.Tenants");
            DropTable("dbo.Properties");
            DropTable("dbo.AspNetUserLogins");
            DropTable("dbo.AspNetUserClaims");
            DropTable("dbo.AspNetUserRoles");
            DropTable("dbo.AspNetRoles");
            DropTable("dbo.AspNetUsers");
        }
    }
}
