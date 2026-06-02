using System.Data.Entity;
using System.Web.Http;
using PropertyManager.Data;
using PropertyManager.Data.Migrations;

namespace PropertyManager.Web
{
    public class WebApiApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            GlobalConfiguration.Configure(WebApiConfig.Register);
            Database.SetInitializer(new MigrateDatabaseToLatestVersion<PropertyManagerContext, Configuration>());
        }
    }
}
