using System;
using System.Collections.Generic;
using System.Linq;
using PropertyManager.Core.Interfaces;
using PropertyManager.Data;
using PropertyManager.Data.Entities;
using PropertyManager.Data.Repositories;

namespace PropertyManager.Core.Services
{
    public class MaintenanceRequestService : IMaintenanceRequestService
    {
        private readonly PropertyManagerContext _context;
        private readonly IMaintenanceRequestRepository _requestRepository;
        private readonly IAttachmentRepository _attachmentRepository;

        public MaintenanceRequestService(PropertyManagerContext context, IMaintenanceRequestRepository requestRepository, IAttachmentRepository attachmentRepository)
        {
            _context = context;
            _requestRepository = requestRepository;
            _attachmentRepository = attachmentRepository;
        }

        public IList<MaintenanceRequest> GetAll(int? status, int? propertyId, int? tenantId, int? priority)
        {
            return _requestRepository.Search(status, propertyId, tenantId, priority).ToList();
        }

        public MaintenanceRequest GetById(int id)
        {
            return _requestRepository.GetWithDetails(id);
        }

        public MaintenanceRequest Create(MaintenanceRequest request)
        {
            request.CreatedDate = DateTime.Now;
            request.Status = RequestStatus.Open;
            _requestRepository.Add(request);
            _requestRepository.Save();
            return request;
        }

        public bool Update(int id, MaintenanceRequest request)
        {
            var existing = _requestRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            existing.Title = request.Title;
            existing.Description = request.Description;
            existing.Priority = request.Priority;
            existing.PropertyId = request.PropertyId;
            existing.TenantId = request.TenantId;
            existing.Notes = request.Notes;
            existing.UpdatedDate = DateTime.Now;

            _requestRepository.Update(existing);
            _requestRepository.Save();
            return true;
        }

        public bool UpdateStatus(int id, RequestStatus status)
        {
            var existing = _requestRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            if (!IsValidTransition(existing.Status, status))
            {
                return false;
            }

            var previousStatus = existing.Status;
            existing.Status = status;
            existing.UpdatedDate = DateTime.Now;

            if (status == RequestStatus.Completed)
            {
                existing.CompletedDate = DateTime.Now;
            }

            _requestRepository.Update(existing);

            var history = new MaintenanceStatusHistory
            {
                MaintenanceRequestId = id,
                FromStatus = previousStatus,
                ToStatus = status,
                ChangedBy = "System",
                ChangedOn = DateTime.Now
            };
            _context.Set<MaintenanceStatusHistory>().Add(history);

            _requestRepository.Save();
            return true;
        }

        public bool Assign(int id, string assignedToId)
        {
            var existing = _requestRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            existing.AssignedToId = assignedToId;
            existing.UpdatedDate = DateTime.Now;
            _requestRepository.Update(existing);
            _requestRepository.Save();
            return true;
        }

        public bool Delete(int id)
        {
            var existing = _requestRepository.GetById(id);
            if (existing == null)
            {
                return false;
            }

            _requestRepository.Delete(existing);
            _requestRepository.Save();
            return true;
        }

        private static bool IsValidTransition(RequestStatus current, RequestStatus next)
        {
            if (current == next)
            {
                return true;
            }

            if (next == RequestStatus.Closed)
            {
                return current == RequestStatus.Open || current == RequestStatus.InProgress || current == RequestStatus.Completed;
            }

            if (current == RequestStatus.Open && next == RequestStatus.InProgress)
            {
                return true;
            }

            if (current == RequestStatus.InProgress && next == RequestStatus.Completed)
            {
                return true;
            }

            return false;
        }
    }
}
