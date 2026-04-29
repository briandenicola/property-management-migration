CREATE TABLE [dbo].[AspNetUsers] (
    [Id] NVARCHAR(128) NOT NULL PRIMARY KEY,
    [Email] NVARCHAR(256) NULL,
    [EmailConfirmed] BIT NOT NULL DEFAULT 0,
    [PasswordHash] NVARCHAR(MAX) NULL,
    [SecurityStamp] NVARCHAR(MAX) NULL,
    [PhoneNumber] NVARCHAR(MAX) NULL,
    [PhoneNumberConfirmed] BIT NOT NULL DEFAULT 0,
    [TwoFactorEnabled] BIT NOT NULL DEFAULT 0,
    [LockoutEndDateUtc] DATETIME NULL,
    [LockoutEnabled] BIT NOT NULL DEFAULT 1,
    [AccessFailedCount] INT NOT NULL DEFAULT 0,
    [UserName] NVARCHAR(256) NOT NULL,
    [FirstName] NVARCHAR(100) NOT NULL,
    [LastName] NVARCHAR(100) NOT NULL,
    [Role] NVARCHAR(50) NULL,
    [IsActive] BIT NOT NULL DEFAULT 1,
    [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE UNIQUE INDEX [IX_AspNetUsers_UserName] ON [dbo].[AspNetUsers]([UserName]);

CREATE TABLE [dbo].[Properties] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [Name] NVARCHAR(200) NOT NULL,
    [Address] NVARCHAR(500) NOT NULL,
    [City] NVARCHAR(100) NOT NULL,
    [State] NVARCHAR(2) NOT NULL,
    [ZipCode] NVARCHAR(10) NOT NULL,
    [Units] INT NOT NULL DEFAULT 1,
    [YearBuilt] INT NULL,
    [IsActive] BIT NOT NULL DEFAULT 1,
    [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [ModifiedDate] DATETIME NULL
);

CREATE TABLE [dbo].[Tenants] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [FirstName] NVARCHAR(100) NOT NULL,
    [LastName] NVARCHAR(100) NOT NULL,
    [Email] NVARCHAR(256) NOT NULL,
    [Phone] NVARCHAR(20) NULL,
    [Unit] NVARCHAR(50) NOT NULL,
    [LeaseStart] DATETIME NOT NULL,
    [LeaseEnd] DATETIME NULL,
    [PropertyId] INT NOT NULL,
    [IsActive] BIT NOT NULL DEFAULT 1,
    [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [FK_Tenants_Properties] FOREIGN KEY ([PropertyId]) REFERENCES [dbo].[Properties]([Id])
);

CREATE TABLE [dbo].[MaintenanceRequests] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [Title] NVARCHAR(200) NOT NULL,
    [Description] NVARCHAR(MAX) NOT NULL,
    [Status] INT NOT NULL DEFAULT 0,
    [Priority] INT NOT NULL DEFAULT 1,
    [TenantId] INT NOT NULL,
    [PropertyId] INT NOT NULL,
    [AssignedToId] NVARCHAR(128) NULL,
    [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [UpdatedDate] DATETIME NULL,
    [CompletedDate] DATETIME NULL,
    [Notes] NVARCHAR(MAX) NULL,
    CONSTRAINT [FK_MaintenanceRequests_Tenants] FOREIGN KEY ([TenantId]) REFERENCES [dbo].[Tenants]([Id]),
    CONSTRAINT [FK_MaintenanceRequests_Properties] FOREIGN KEY ([PropertyId]) REFERENCES [dbo].[Properties]([Id]),
    CONSTRAINT [FK_MaintenanceRequests_AspNetUsers] FOREIGN KEY ([AssignedToId]) REFERENCES [dbo].[AspNetUsers]([Id])
);

CREATE INDEX [IX_MaintenanceRequests_Status] ON [dbo].[MaintenanceRequests]([Status]);
CREATE INDEX [IX_MaintenanceRequests_PropertyId] ON [dbo].[MaintenanceRequests]([PropertyId]);
CREATE INDEX [IX_MaintenanceRequests_TenantId] ON [dbo].[MaintenanceRequests]([TenantId]);

CREATE TABLE [dbo].[Attachments] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [FileName] NVARCHAR(256) NOT NULL,
    [ContentType] NVARCHAR(100) NOT NULL,
    [FileSize] BIGINT NOT NULL,
    [FileData] VARBINARY(MAX) NOT NULL,
    [MaintenanceRequestId] INT NOT NULL,
    [UploadedDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [UploadedById] NVARCHAR(128) NULL,
    CONSTRAINT [FK_Attachments_MaintenanceRequests] FOREIGN KEY ([MaintenanceRequestId]) REFERENCES [dbo].[MaintenanceRequests]([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_Attachments_AspNetUsers] FOREIGN KEY ([UploadedById]) REFERENCES [dbo].[AspNetUsers]([Id])
);

CREATE INDEX [IX_Attachments_MaintenanceRequestId] ON [dbo].[Attachments]([MaintenanceRequestId]);
