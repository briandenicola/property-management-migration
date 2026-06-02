using PropertyManager.Core.Interfaces;
using PropertyManager.Core.Services;
using PropertyManager.Data;
using PropertyManager.Data.Repositories;

namespace PropertyManager.Web
{
    public static class LegacyServiceLocator
    {
        public static IPropertyService GetPropertyService()
        {
            var context = new PropertyManagerContext();
            return new PropertyService(context, new PropertyRepository(context), new TenantRepository(context));
        }

        public static ITenantService GetTenantService()
        {
            var context = new PropertyManagerContext();
            return new TenantService(context, new TenantRepository(context));
        }

        public static IMaintenanceRequestService GetMaintenanceRequestService()
        {
            var context = new PropertyManagerContext();
            return new MaintenanceRequestService(context, new MaintenanceRequestRepository(context), new AttachmentRepository(context));
        }

        public static IAttachmentService GetAttachmentService()
        {
            var context = new PropertyManagerContext();
            return new AttachmentService(context, new AttachmentRepository(context));
        }
    }
}
