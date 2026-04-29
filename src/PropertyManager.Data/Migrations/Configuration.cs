using System.Data.Entity.Migrations;

namespace PropertyManager.Data.Migrations
{
    internal sealed class Configuration : DbMigrationsConfiguration<PropertyManager.Data.PropertyManagerContext>
    {
        public Configuration()
        {
            AutomaticMigrationsEnabled = false;
            ContextKey = "PropertyManager.Data.PropertyManagerContext";
        }

        protected override void Seed(PropertyManager.Data.PropertyManagerContext context)
        {
        }
    }
}
