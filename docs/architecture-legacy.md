# Legacy Architecture — Property Management Application

> **Version:** 1.0  
> **Era:** ~2015 (.NET Framework 4.6, AngularJS 1.x)  
> **Status:** Blueprint for legacy app build  
> **Author:** McClane (Lead Architect)  
> **Date:** 2026-04-29

---

## 1. Overview

This document defines the architecture of the **PropertyPro** property management application as it exists in its legacy state — a typical enterprise line-of-business app built circa 2015, deployed on Windows Server with IIS.

The app manages rental properties, tenants, maintenance requests (with photo/document uploads), and property manager workflows. It's a single-page application (SPA) with an AngularJS frontend and a .NET Framework Web API 2 backend. Files are stored as binary blobs directly in SQL Server — the key anti-pattern that will drive our migration story.

---

## 2. Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Frontend Framework | AngularJS | 1.5.x |
| UI Library | Bootstrap | 3.3.7 |
| DOM Manipulation | jQuery | 2.2.4 |
| Build/Package | Bower + Grunt | — |
| Backend Framework | .NET Framework | 4.6.1 |
| Web Framework | ASP.NET Web API 2 | 5.2.x |
| ORM | Entity Framework | 6.1.3 |
| Database | SQL Server | 2014+ |
| Hosting | IIS | 8.5+ on Windows Server 2012 R2 |
| Auth | ASP.NET Identity (cookie-based) | 2.2.x |
| DI Container | Unity | 4.x (minimal usage) |
| Package Manager | NuGet | — |

---

## 3. Solution Structure

```
PropertyPro.sln
│
├── PropertyPro.Web/                    # Main Web API + SPA host project
│   ├── App_Start/
│   │   ├── WebApiConfig.cs            # Route configuration
│   │   ├── UnityConfig.cs             # DI registration (Unity container)
│   │   ├── BundleConfig.cs            # JS/CSS bundling
│   │   └── FilterConfig.cs            # Global filters
│   ├── Controllers/
│   │   ├── PropertiesController.cs
│   │   ├── TenantsController.cs
│   │   ├── MaintenanceRequestsController.cs
│   │   ├── AttachmentsController.cs
│   │   ├── UsersController.cs
│   │   └── AccountController.cs       # Login/logout
│   ├── Models/
│   │   ├── Property.cs
│   │   ├── Tenant.cs
│   │   ├── MaintenanceRequest.cs
│   │   ├── Attachment.cs
│   │   ├── User.cs
│   │   └── DTOs/                      # View models / DTOs
│   │       ├── PropertyDto.cs
│   │       ├── TenantDto.cs
│   │       ├── MaintenanceRequestDto.cs
│   │       ├── AttachmentDto.cs       # Metadata only (no blob)
│   │       └── CreateMaintenanceRequestDto.cs
│   ├── Data/
│   │   ├── PropertyProDbContext.cs    # EF6 DbContext
│   │   ├── Migrations/               # EF Code First migrations
│   │   │   ├── Configuration.cs
│   │   │   ├── 201504_InitialCreate.cs
│   │   │   └── 201506_AddAttachments.cs
│   │   └── Seed/
│   │       └── SeedData.cs           # Dev seed data
│   ├── Services/
│   │   ├── IMaintenanceService.cs
│   │   ├── MaintenanceService.cs
│   │   ├── IAttachmentService.cs
│   │   └── AttachmentService.cs       # Reads/writes blobs to SQL
│   ├── app/                           # AngularJS SPA (served as static files)
│   │   ├── app.module.js             # Angular module definition
│   │   ├── app.config.js             # Route config (ui-router)
│   │   ├── app.run.js                # Run block (auth check)
│   │   ├── components/
│   │   │   ├── properties/
│   │   │   │   ├── properties.module.js
│   │   │   │   ├── property-list.component.js
│   │   │   │   ├── property-list.html
│   │   │   │   ├── property-detail.component.js
│   │   │   │   └── property-detail.html
│   │   │   ├── tenants/
│   │   │   │   ├── tenants.module.js
│   │   │   │   ├── tenant-list.component.js
│   │   │   │   ├── tenant-list.html
│   │   │   │   ├── tenant-form.component.js
│   │   │   │   └── tenant-form.html
│   │   │   ├── maintenance/
│   │   │   │   ├── maintenance.module.js
│   │   │   │   ├── request-list.component.js
│   │   │   │   ├── request-list.html
│   │   │   │   ├── request-detail.component.js
│   │   │   │   ├── request-detail.html
│   │   │   │   ├── request-form.component.js
│   │   │   │   └── request-form.html
│   │   │   └── shared/
│   │   │       ├── navbar.component.js
│   │   │       ├── navbar.html
│   │   │       ├── file-upload.directive.js
│   │   │       └── loading-spinner.directive.js
│   │   ├── services/
│   │   │   ├── property.service.js
│   │   │   ├── tenant.service.js
│   │   │   ├── maintenance.service.js
│   │   │   ├── attachment.service.js
│   │   │   └── auth.service.js
│   │   └── filters/
│   │       ├── status-badge.filter.js
│   │       └── date-format.filter.js
│   ├── Content/
│   │   ├── bootstrap.css
│   │   ├── site.css                   # Custom overrides
│   │   └── images/
│   ├── Scripts/
│   │   ├── angular.js
│   │   ├── angular-ui-router.js
│   │   ├── jquery-2.2.4.js
│   │   ├── bootstrap.js
│   │   └── toastr.js                  # Notification library
│   ├── Views/
│   │   └── Index.html                 # SPA shell page (layout)
│   ├── Global.asax
│   ├── Global.asax.cs                 # Application_Start
│   ├── Startup.cs                     # OWIN startup (if used)
│   ├── Web.config                     # IIS config, connection strings, app settings
│   ├── packages.config                # NuGet packages
│   └── PropertyPro.Web.csproj
│
├── PropertyPro.Tests/                  # Unit test project (sparse — it's legacy)
│   ├── Controllers/
│   │   └── PropertiesControllerTests.cs
│   └── PropertyPro.Tests.csproj
│
├── .gitignore
├── README.md
└── PropertyPro.sln
```

---

## 4. Domain Model

### 4.1 Entity Relationship Diagram (Conceptual)

```
┌──────────────┐       ┌──────────────┐       ┌─────────────────────┐
│   Property   │ 1───* │    Tenant    │ 1───* │ MaintenanceRequest  │
├──────────────┤       ├──────────────┤       ├─────────────────────┤
│ Id (int)     │       │ Id (int)     │       │ Id (int)            │
│ Name         │       │ FirstName    │       │ Title               │
│ Address      │       │ LastName     │       │ Description         │
│ City         │       │ Email        │       │ Status (enum)       │
│ State        │       │ Phone        │       │ Priority (enum)     │
│ ZipCode      │       │ Unit         │       │ TenantId (FK)       │
│ Units (int)  │       │ LeaseStart   │       │ PropertyId (FK)     │
│ YearBuilt    │       │ LeaseEnd     │       │ AssignedToId (FK)   │
│ IsActive     │       │ PropertyId   │       │ CreatedDate         │
│ CreatedDate  │       │ IsActive     │       │ UpdatedDate         │
│ ModifiedDate │       │ CreatedDate  │       │ CompletedDate       │
└──────────────┘       └──────────────┘       │ Notes               │
                                               └─────────────────────┘
                                                        │
                                                        │ 1───*
                                                        ▼
                                               ┌─────────────────────┐
                                               │    Attachment       │
                                               ├─────────────────────┤
                                               │ Id (int)            │
                                               │ FileName            │
                                               │ ContentType         │
                                               │ FileSize (long)     │
                                               │ FileData (byte[])   │  ← varbinary(MAX)
                                               │ MaintenanceRequestId│
                                               │ UploadedDate        │
                                               │ UploadedById (FK)   │
                                               └─────────────────────┘

┌──────────────┐
│     User     │  (Property Managers / Admin)
├──────────────┤
│ Id (string)  │  ← ASP.NET Identity GUID
│ Email        │
│ FirstName    │
│ LastName     │
│ Role         │  (Admin, Manager)
│ IsActive     │
│ CreatedDate  │
└──────────────┘
```

### 4.2 Status Workflow — Maintenance Requests

```
   ┌────────┐      ┌─────────────┐      ┌───────────┐      ┌────────┐
   │  Open  │ ───► │ In Progress │ ───► │ Completed │ ───► │ Closed │
   └────────┘      └─────────────┘      └───────────┘      └────────┘
       │                                                         ▲
       └─────────────────────────────────────────────────────────┘
                          (can close directly if invalid)
```

**Status enum values:** `Open = 0`, `InProgress = 1`, `Completed = 2`, `Closed = 3`

**Priority enum values:** `Low = 0`, `Medium = 1`, `High = 2`, `Emergency = 3`

---

## 5. Database Schema

### 5.1 Key Tables

```sql
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
    [PropertyId] INT NOT NULL FOREIGN KEY REFERENCES [Properties]([Id]),
    [IsActive] BIT NOT NULL DEFAULT 1,
    [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE [dbo].[MaintenanceRequests] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [Title] NVARCHAR(200) NOT NULL,
    [Description] NVARCHAR(MAX) NOT NULL,
    [Status] INT NOT NULL DEFAULT 0,
    [Priority] INT NOT NULL DEFAULT 1,
    [TenantId] INT NOT NULL FOREIGN KEY REFERENCES [Tenants]([Id]),
    [PropertyId] INT NOT NULL FOREIGN KEY REFERENCES [Properties]([Id]),
    [AssignedToId] NVARCHAR(128) NULL FOREIGN KEY REFERENCES [AspNetUsers]([Id]),
    [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [UpdatedDate] DATETIME NULL,
    [CompletedDate] DATETIME NULL,
    [Notes] NVARCHAR(MAX) NULL
);

-- THE KEY ANTI-PATTERN: Binary file data stored directly in SQL Server
CREATE TABLE [dbo].[Attachments] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [FileName] NVARCHAR(256) NOT NULL,
    [ContentType] NVARCHAR(100) NOT NULL,
    [FileSize] BIGINT NOT NULL,
    [FileData] VARBINARY(MAX) NOT NULL,          -- ← THIS IS THE PROBLEM
    [MaintenanceRequestId] INT NOT NULL FOREIGN KEY REFERENCES [MaintenanceRequests]([Id]),
    [UploadedDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [UploadedById] NVARCHAR(128) NULL FOREIGN KEY REFERENCES [AspNetUsers]([Id])
);
```

### 5.2 Why Blobs in SQL is the Anti-Pattern

- Database backups become enormous (multi-GB with images)
- SQL Server memory pressure from streaming large blobs
- Cannot leverage CDN or edge caching
- Transaction log bloat on every upload
- Backup/restore times scale with attachment volume
- No easy way to serve files directly to browsers without API intermediary

---

## 6. API Surface

### Base URL: `/api`

### 6.1 Properties

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/properties` | List all properties (supports `?search=`, `?isActive=`) |
| GET | `/api/properties/{id}` | Get property by ID (includes tenant count) |
| POST | `/api/properties` | Create new property |
| PUT | `/api/properties/{id}` | Update property |
| DELETE | `/api/properties/{id}` | Soft-delete property (set IsActive=false) |

### 6.2 Tenants

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tenants` | List tenants (supports `?propertyId=`, `?search=`) |
| GET | `/api/tenants/{id}` | Get tenant by ID |
| POST | `/api/tenants` | Create tenant |
| PUT | `/api/tenants/{id}` | Update tenant |
| DELETE | `/api/tenants/{id}` | Soft-delete tenant |
| GET | `/api/properties/{id}/tenants` | Get tenants for a property |

### 6.3 Maintenance Requests

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/maintenancerequests` | List requests (supports `?status=`, `?propertyId=`, `?tenantId=`, `?priority=`) |
| GET | `/api/maintenancerequests/{id}` | Get request by ID (includes attachment metadata) |
| POST | `/api/maintenancerequests` | Create request |
| PUT | `/api/maintenancerequests/{id}` | Update request |
| PUT | `/api/maintenancerequests/{id}/status` | Update status only (workflow transition) |
| PUT | `/api/maintenancerequests/{id}/assign` | Assign to a user |
| DELETE | `/api/maintenancerequests/{id}` | Delete request (admin only) |

### 6.4 Attachments (File Upload/Download)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/maintenancerequests/{id}/attachments` | List attachment metadata for a request |
| GET | `/api/attachments/{id}` | Download file (streams from varbinary) |
| POST | `/api/maintenancerequests/{id}/attachments` | Upload file (multipart/form-data → varbinary) |
| DELETE | `/api/attachments/{id}` | Delete attachment |

**Upload details:**
- Content-Type: `multipart/form-data`
- Max file size: 10MB (configured in web.config `maxRequestLength`)
- Accepted types: `.jpg`, `.jpeg`, `.png`, `.gif`, `.pdf`, `.doc`, `.docx`
- The entire file byte array is read into memory and stored in `[FileData]` column

### 6.5 Account / Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/account/login` | Login (returns cookie) |
| POST | `/api/account/logout` | Logout (clears cookie) |
| GET | `/api/account/userinfo` | Get current user info |

---

## 7. Backend Implementation Patterns

### 7.1 Controller Pattern (Typical)

```csharp
// Controllers/MaintenanceRequestsController.cs
[RoutePrefix("api/maintenancerequests")]
public class MaintenanceRequestsController : ApiController
{
    private readonly PropertyProDbContext _context;

    // Direct DbContext injection — no repository pattern
    public MaintenanceRequestsController()
    {
        _context = new PropertyProDbContext();  // Sometimes just newed up
    }

    [HttpGet]
    [Route("")]
    public IHttpActionResult GetAll(int? status = null, int? propertyId = null)
    {
        var query = _context.MaintenanceRequests
            .Include("Tenant")
            .Include("Property")
            .AsQueryable();

        if (status.HasValue)
            query = query.Where(r => r.Status == (RequestStatus)status.Value);

        if (propertyId.HasValue)
            query = query.Where(r => r.PropertyId == propertyId.Value);

        // Manual mapping to DTO (no AutoMapper)
        var results = query.ToList().Select(r => new MaintenanceRequestDto
        {
            Id = r.Id,
            Title = r.Title,
            Status = r.Status.ToString(),
            TenantName = r.Tenant.FirstName + " " + r.Tenant.LastName,
            PropertyName = r.Property.Name,
            CreatedDate = r.CreatedDate
        });

        return Ok(results);
    }

    protected override void Dispose(bool disposing)
    {
        _context.Dispose();
        base.Dispose(disposing);
    }
}
```

### 7.2 Attachment Upload (The Anti-Pattern in Action)

```csharp
// Controllers/AttachmentsController.cs
[HttpPost]
[Route("api/maintenancerequests/{requestId}/attachments")]
public async Task<IHttpActionResult> Upload(int requestId)
{
    if (!Request.Content.IsMimeMultipartContent())
        return BadRequest("Expected multipart content");

    var provider = new MultipartMemoryStreamProvider();
    await Request.Content.ReadAsMultipartAsync(provider);

    var file = provider.Contents.FirstOrDefault();
    if (file == null)
        return BadRequest("No file uploaded");

    var fileName = file.Headers.ContentDisposition.FileName.Trim('"');
    var fileBytes = await file.ReadAsByteArrayAsync();  // ENTIRE FILE IN MEMORY

    var attachment = new Attachment
    {
        FileName = fileName,
        ContentType = file.Headers.ContentType.MediaType,
        FileSize = fileBytes.Length,
        FileData = fileBytes,  // Stored directly as varbinary(MAX)
        MaintenanceRequestId = requestId,
        UploadedDate = DateTime.Now,
        UploadedById = User.Identity.GetUserId()
    };

    _context.Attachments.Add(attachment);
    _context.SaveChanges();  // NOT async — common in legacy code

    return Ok(new AttachmentDto
    {
        Id = attachment.Id,
        FileName = attachment.FileName,
        FileSize = attachment.FileSize,
        UploadedDate = attachment.UploadedDate
    });
}
```

### 7.3 File Download (Streaming from DB)

```csharp
[HttpGet]
[Route("api/attachments/{id}")]
public IHttpActionResult Download(int id)
{
    var attachment = _context.Attachments.Find(id);
    if (attachment == null)
        return NotFound();

    var response = new HttpResponseMessage(HttpStatusCode.OK)
    {
        Content = new ByteArrayContent(attachment.FileData)
    };
    response.Content.Headers.ContentType = new MediaTypeHeaderValue(attachment.ContentType);
    response.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
    {
        FileName = attachment.FileName
    };

    return ResponseMessage(response);
}
```

### 7.4 DbContext

```csharp
// Data/PropertyProDbContext.cs
public class PropertyProDbContext : DbContext
{
    public PropertyProDbContext() : base("name=PropertyProConnection")
    {
    }

    public DbSet<Property> Properties { get; set; }
    public DbSet<Tenant> Tenants { get; set; }
    public DbSet<MaintenanceRequest> MaintenanceRequests { get; set; }
    public DbSet<Attachment> Attachments { get; set; }

    protected override void OnModelCreating(DbModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Attachment>()
            .Property(a => a.FileData)
            .IsRequired();

        modelBuilder.Entity<MaintenanceRequest>()
            .HasMany(r => r.Attachments)
            .WithRequired(a => a.MaintenanceRequest)
            .HasForeignKey(a => a.MaintenanceRequestId);
    }
}
```

### 7.5 Web.config (Key Sections)

```xml
<configuration>
  <connectionStrings>
    <!-- Connection string right here in plain text — no secrets management -->
    <add name="PropertyProConnection"
         connectionString="Server=.\SQLEXPRESS;Database=PropertyPro;Integrated Security=True;"
         providerName="System.Data.SqlClient" />
  </connectionStrings>

  <appSettings>
    <add key="MaxFileUploadSize" value="10485760" />
    <add key="AllowedFileExtensions" value=".jpg,.jpeg,.png,.gif,.pdf,.doc,.docx" />
  </appSettings>

  <system.web>
    <!-- Allow large file uploads -->
    <httpRuntime maxRequestLength="11264" targetFramework="4.6.1" />
  </system.web>

  <system.webServer>
    <security>
      <requestFiltering>
        <requestLimits maxAllowedContentLength="11534336" />
      </requestFiltering>
    </security>
    <handlers>
      <remove name="ExtensionlessUrlHandler-Integrated-4.0" />
      <add name="ExtensionlessUrlHandler-Integrated-4.0" path="*."
           verb="*" type="System.Web.Handlers.TransferRequestHandler"
           preCondition="integratedMode,runtimeVersionv4.0" />
    </handlers>
  </system.webServer>
</configuration>
```

### 7.6 Global.asax.cs

```csharp
public class WebApiApplication : System.Web.HttpApplication
{
    protected void Application_Start()
    {
        GlobalConfiguration.Configure(WebApiConfig.Register);
        FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
        BundleConfig.RegisterBundles(BundleTable.Bundles);

        // EF Migrations — auto-migrate on startup (yikes)
        Database.SetInitializer(new MigrateDatabaseToLatestVersion<PropertyProDbContext, Configuration>());
    }
}
```

### 7.7 WebApiConfig.cs

```csharp
public static class WebApiConfig
{
    public static void Register(HttpConfiguration config)
    {
        // Unity DI
        var container = new UnityContainer();
        container.RegisterType<PropertyProDbContext>(new HierarchicalLifetimeManager());
        config.DependencyResolver = new UnityDependencyResolver(container);

        // JSON formatting
        config.Formatters.JsonFormatter.SerializerSettings.ContractResolver =
            new CamelCasePropertyNamesContractResolver();
        config.Formatters.Remove(config.Formatters.XmlFormatter);

        // Attribute routing
        config.MapHttpAttributeRoutes();

        // Convention routes
        config.Routes.MapHttpRoute(
            name: "DefaultApi",
            routeTemplate: "api/{controller}/{id}",
            defaults: new { id = RouteParameter.Optional }
        );

        // CORS (wide open — legacy style)
        var cors = new EnableCorsAttribute("*", "*", "*");
        config.EnableCors(cors);
    }
}
```

---

## 8. Frontend Implementation Patterns

### 8.1 App Module

```javascript
// app/app.module.js
(function() {
    'use strict';

    angular.module('propertyPro', [
        'ui.router',
        'propertyPro.properties',
        'propertyPro.tenants',
        'propertyPro.maintenance',
        'propertyPro.shared'
    ]);
})();
```

### 8.2 Route Config (UI-Router)

```javascript
// app/app.config.js
(function() {
    'use strict';

    angular.module('propertyPro')
        .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {

            $urlRouterProvider.otherwise('/properties');

            $stateProvider
                .state('properties', {
                    url: '/properties',
                    template: '<property-list></property-list>'
                })
                .state('propertyDetail', {
                    url: '/properties/:id',
                    template: '<property-detail></property-detail>'
                })
                .state('tenants', {
                    url: '/tenants',
                    template: '<tenant-list></tenant-list>'
                })
                .state('maintenance', {
                    url: '/maintenance',
                    template: '<request-list></request-list>'
                })
                .state('maintenanceDetail', {
                    url: '/maintenance/:id',
                    template: '<request-detail></request-detail>'
                })
                .state('maintenanceNew', {
                    url: '/maintenance/new',
                    template: '<request-form></request-form>'
                })
                .state('login', {
                    url: '/login',
                    templateUrl: 'app/components/auth/login.html',
                    controller: 'LoginController',
                    controllerAs: 'vm'
                });
        }]);
})();
```

### 8.3 Service Pattern (Using $http)

```javascript
// app/services/maintenance.service.js
(function() {
    'use strict';

    angular.module('propertyPro')
        .factory('maintenanceService', ['$http', function($http) {
            var baseUrl = '/api/maintenancerequests';

            return {
                getAll: function(params) {
                    return $http.get(baseUrl, { params: params });
                },
                getById: function(id) {
                    return $http.get(baseUrl + '/' + id);
                },
                create: function(request) {
                    return $http.post(baseUrl, request);
                },
                update: function(id, request) {
                    return $http.put(baseUrl + '/' + id, request);
                },
                updateStatus: function(id, status) {
                    return $http.put(baseUrl + '/' + id + '/status', { status: status });
                }
            };
        }]);
})();
```

### 8.4 File Upload Service (jQuery + Angular Hybrid)

```javascript
// app/services/attachment.service.js
(function() {
    'use strict';

    angular.module('propertyPro')
        .factory('attachmentService', ['$http', '$q', function($http, $q) {
            return {
                upload: function(requestId, file) {
                    var deferred = $q.defer();
                    var formData = new FormData();
                    formData.append('file', file);

                    // Using jQuery ajax for file upload (common pattern in 2015)
                    $.ajax({
                        url: '/api/maintenancerequests/' + requestId + '/attachments',
                        type: 'POST',
                        data: formData,
                        processData: false,
                        contentType: false,
                        success: function(data) {
                            deferred.resolve(data);
                        },
                        error: function(xhr) {
                            deferred.reject(xhr.responseJSON);
                        }
                    });

                    return deferred.promise;
                },
                getForRequest: function(requestId) {
                    return $http.get('/api/maintenancerequests/' + requestId + '/attachments');
                },
                getDownloadUrl: function(attachmentId) {
                    return '/api/attachments/' + attachmentId;
                },
                delete: function(attachmentId) {
                    return $http.delete('/api/attachments/' + attachmentId);
                }
            };
        }]);
})();
```

### 8.5 Component Pattern (AngularJS 1.5+)

```javascript
// app/components/maintenance/request-detail.component.js
(function() {
    'use strict';

    angular.module('propertyPro.maintenance')
        .component('requestDetail', {
            templateUrl: 'app/components/maintenance/request-detail.html',
            controller: RequestDetailController
        });

    RequestDetailController.$inject = ['$stateParams', 'maintenanceService', 'attachmentService', 'toastr'];

    function RequestDetailController($stateParams, maintenanceService, attachmentService, toastr) {
        var vm = this;
        vm.request = null;
        vm.attachments = [];
        vm.loading = true;

        vm.$onInit = function() {
            loadRequest();
        };

        vm.updateStatus = function(newStatus) {
            maintenanceService.updateStatus(vm.request.id, newStatus)
                .then(function() {
                    vm.request.status = newStatus;
                    toastr.success('Status updated');
                })
                .catch(function() {
                    toastr.error('Failed to update status');
                });
        };

        vm.uploadFile = function(file) {
            attachmentService.upload(vm.request.id, file)
                .then(function(attachment) {
                    vm.attachments.push(attachment);
                    toastr.success('File uploaded');
                })
                .catch(function() {
                    toastr.error('Upload failed');
                });
        };

        vm.getDownloadUrl = attachmentService.getDownloadUrl;

        function loadRequest() {
            maintenanceService.getById($stateParams.id)
                .then(function(response) {
                    vm.request = response.data;
                    return attachmentService.getForRequest($stateParams.id);
                })
                .then(function(response) {
                    vm.attachments = response.data;
                })
                .finally(function() {
                    vm.loading = false;
                });
        }
    }
})();
```

### 8.6 HTML Template (Bootstrap 3)

```html
<!-- app/components/maintenance/request-detail.html -->
<div class="container" ng-if="!$ctrl.loading">
    <div class="row">
        <div class="col-md-8">
            <div class="panel panel-default">
                <div class="panel-heading">
                    <h3 class="panel-title">
                        {{$ctrl.request.title}}
                        <span class="label" ng-class="{
                            'label-warning': $ctrl.request.status === 'Open',
                            'label-info': $ctrl.request.status === 'InProgress',
                            'label-success': $ctrl.request.status === 'Completed',
                            'label-default': $ctrl.request.status === 'Closed'
                        }">{{$ctrl.request.status}}</span>
                    </h3>
                </div>
                <div class="panel-body">
                    <p>{{$ctrl.request.description}}</p>
                    <dl class="dl-horizontal">
                        <dt>Property</dt>
                        <dd>{{$ctrl.request.propertyName}}</dd>
                        <dt>Tenant</dt>
                        <dd>{{$ctrl.request.tenantName}}</dd>
                        <dt>Priority</dt>
                        <dd>{{$ctrl.request.priority}}</dd>
                        <dt>Created</dt>
                        <dd>{{$ctrl.request.createdDate | date:'medium'}}</dd>
                    </dl>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <!-- Status Actions -->
            <div class="panel panel-default">
                <div class="panel-heading">Actions</div>
                <div class="panel-body">
                    <button class="btn btn-primary btn-block"
                            ng-click="$ctrl.updateStatus('InProgress')"
                            ng-show="$ctrl.request.status === 'Open'">
                        Start Work
                    </button>
                    <button class="btn btn-success btn-block"
                            ng-click="$ctrl.updateStatus('Completed')"
                            ng-show="$ctrl.request.status === 'InProgress'">
                        Mark Complete
                    </button>
                    <button class="btn btn-default btn-block"
                            ng-click="$ctrl.updateStatus('Closed')">
                        Close
                    </button>
                </div>
            </div>

            <!-- Attachments -->
            <div class="panel panel-default">
                <div class="panel-heading">Attachments</div>
                <div class="panel-body">
                    <ul class="list-group" ng-if="$ctrl.attachments.length">
                        <li class="list-group-item" ng-repeat="att in $ctrl.attachments">
                            <a ng-href="{{$ctrl.getDownloadUrl(att.id)}}" target="_blank">
                                <i class="glyphicon glyphicon-paperclip"></i>
                                {{att.fileName}}
                            </a>
                            <span class="badge">{{att.fileSize | number}} bytes</span>
                        </li>
                    </ul>
                    <p ng-if="!$ctrl.attachments.length" class="text-muted">No attachments</p>
                    <hr>
                    <input type="file" file-upload on-select="$ctrl.uploadFile(file)">
                </div>
            </div>
        </div>
    </div>
</div>
<div class="text-center" ng-if="$ctrl.loading">
    <loading-spinner></loading-spinner>
</div>
```

---

## 9. Deployment & Hosting

### 9.1 IIS Configuration

- **App Pool:** .NET CLR v4.0, Integrated Pipeline Mode
- **Site Binding:** HTTP on port 80 (HTTPS via IIS certificate binding if configured)
- **Physical Path:** `C:\inetpub\wwwroot\PropertyPro`
- **Auth:** Windows Auth disabled, Anonymous enabled (app handles auth via cookies)

### 9.2 Deployment Process (Era-Appropriate)

1. Build in Visual Studio (or MSBuild on build server)
2. Publish via Web Deploy (MSDeploy) or "Copy to folder" 
3. Manually run EF migrations (or auto-migrate on startup via `Database.SetInitializer`)
4. Restart IIS app pool after deployment

### 9.3 No CI/CD (Or Maybe TeamCity/Jenkins)

- No containerization
- No infrastructure-as-code
- Possibly a basic build script using MSBuild
- Database changes via EF migrations run locally against production (yikes)

---

## 10. Era-Appropriate Patterns & Anti-Patterns

### 10.1 Anti-Patterns (Intentional — These Drive the Migration)

| Anti-Pattern | Description | Migration Target |
|-------------|-------------|-----------------|
| **Blobs in SQL** | File data stored as `varbinary(MAX)` | Azure Blob Storage |
| **No async** | Synchronous DB calls (`SaveChanges()` not `SaveChangesAsync()`) | Async/await throughout |
| **Secrets in config** | Connection strings in `web.config` | Azure Key Vault / App Settings |
| **No DI everywhere** | Some controllers `new` up the DbContext directly | Built-in .NET DI |
| **Tight coupling** | Controllers directly reference EF context | Repository/Service pattern |
| **No health checks** | No `/health` endpoint | ASP.NET Core health checks |
| **No structured logging** | `System.Diagnostics.Trace` or nothing | Serilog + Application Insights |
| **Global error handling** | Catch-all in `Global.asax` | Middleware pipeline |
| **jQuery + Angular** | Mixed DOM manipulation approaches | Modern Angular only |
| **IIFE pattern** | Immediately-invoked functions everywhere | ES modules / TypeScript |
| **No TypeScript** | Plain JavaScript with no type safety | Full TypeScript |
| **Bower + Grunt** | Dead package managers | npm + Angular CLI |

### 10.2 Patterns That ARE Era-Appropriate (Keep Them Authentic)

- IIFE wrapping for AngularJS modules (avoids global scope pollution)
- `controllerAs` syntax with `vm` variable
- AngularJS 1.5 `.component()` API (progressive, but still AngularJS)
- UI-Router for SPA routing (better than `ngRoute` for complex apps)
- Bootstrap 3 panels, glyphicons, grid system
- Attribute routing on Web API controllers
- `[RoutePrefix]` for controller-level route segments
- Entity Framework Code First with migrations
- Unity for DI (registered in `App_Start`)
- Cookie-based auth with ASP.NET Identity
- `toastr.js` for notifications

---

## 11. Build Instructions

### For Karl (Backend):
1. Create the .NET Framework 4.6.1 Web API project in Visual Studio 2015/2017
2. Install NuGet packages: `Microsoft.AspNet.WebApi`, `EntityFramework`, `Unity.WebApi`, `Microsoft.AspNet.Identity.EntityFramework`, `Microsoft.AspNet.Cors`
3. Implement entities, DbContext, and migrations
4. Implement controllers following the patterns above
5. Ensure file upload/download works with `varbinary(MAX)`
6. Connection string in `web.config` pointing to LocalDB for dev

### For Argyle (Frontend):
1. Create the `/app` folder structure within the Web API project
2. Use Bower for AngularJS, UI-Router, jQuery, Bootstrap 3, Toastr
3. Use Grunt for concatenation/minification (or just serve raw files in dev)
4. Implement components following the AngularJS 1.5 component pattern
5. Use `$http` for API calls, jQuery `$.ajax` for file uploads
6. Bootstrap 3 styling — panels, alerts, forms, glyphicons

### For Theo (DevOps):
1. Ensure the solution builds with MSBuild
2. `web.config` transformations for different environments (if we go that far)
3. IIS Express for local dev (built into VS)
4. Document the IIS deployment steps
5. No Docker, no Azure, no CI/CD — this is the "before" state

---

## 12. Key File Paths Reference

| File | Purpose |
|------|---------|
| `PropertyPro.sln` | Solution root |
| `PropertyPro.Web/Web.config` | All configuration (connection strings, app settings) |
| `PropertyPro.Web/Global.asax.cs` | Application startup |
| `PropertyPro.Web/App_Start/WebApiConfig.cs` | Route registration, DI, formatters |
| `PropertyPro.Web/Data/PropertyProDbContext.cs` | EF6 database context |
| `PropertyPro.Web/Controllers/AttachmentsController.cs` | File upload/download (the key migration target) |
| `PropertyPro.Web/app/app.module.js` | AngularJS app entry point |
| `PropertyPro.Web/app/services/` | API communication layer |
| `PropertyPro.Web/Views/Index.html` | SPA shell (loads all scripts) |

---

*This document is the single source of truth for the legacy application architecture. All implementation work should reference this blueprint.*
