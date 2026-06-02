using System;
using System.Data.Entity;
using System.Linq;

namespace PropertyManager.Data.Repositories
{
    public class GenericRepository<TEntity> where TEntity : class
    {
        protected readonly PropertyManagerContext Context;
        protected readonly DbSet<TEntity> Set;

        public GenericRepository(PropertyManagerContext context)
        {
            Context = context;
            Set = context.Set<TEntity>();
        }

        public virtual IQueryable<TEntity> Query()
        {
            return Set.AsQueryable();
        }

        public virtual TEntity GetById(object id)
        {
            return Set.Find(id);
        }

        public virtual void Add(TEntity entity)
        {
            Set.Add(entity);
        }

        public virtual void Update(TEntity entity)
        {
            Context.Entry(entity).State = EntityState.Modified;
        }

        public virtual void Delete(TEntity entity)
        {
            Set.Remove(entity);
        }

        public virtual int Save()
        {
            return Context.SaveChanges();
        }
    }
}
