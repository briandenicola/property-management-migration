using System.Linq;
using System.Web.Http;
using PropertyManager.Core.Interfaces;
using PropertyManager.Data.Entities;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [RoutePrefix("api/maintenancerequests")]
    public class MaintenanceRequestsController : ApiController
    {
        private readonly IMaintenanceRequestService _requestService;

        public MaintenanceRequestsController()
        {
            _requestService = LegacyServiceLocator.GetMaintenanceRequestService();
        }

        [HttpGet]
        [Route("")]
        public IHttpActionResult GetAll(int? status = null, int? propertyId = null, int? tenantId = null, int? priority = null)
        {
            var results = _requestService.GetAll(status, propertyId, tenantId, priority)
                .Select(MapToDto)
                .ToList();
            return Ok(results);
        }

        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult GetById(int id)
        {
            var request = _requestService.GetById(id);
            if (request == null)
            {
                return NotFound();
            }

            return Ok(MapToDto(request));
        }

        [HttpPost]
        [Route("")]
        public IHttpActionResult Create(MaintenanceRequestDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Request is required.");
            }

            var entity = new MaintenanceRequest
            {
                Title = dto.Title,
                Description = dto.Description,
                TenantId = dto.TenantId,
                PropertyId = dto.PropertyId,
                Priority = (RequestPriority)dto.Priority,
                Notes = dto.Notes
            };

            var created = _requestService.Create(entity);
            return Created($"/api/maintenancerequests/{created.Id}", MapToDto(created));
        }

        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Update(int id, MaintenanceRequestDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Request is required.");
            }

            var entity = new MaintenanceRequest
            {
                Title = dto.Title,
                Description = dto.Description,
                TenantId = dto.TenantId,
                PropertyId = dto.PropertyId,
                Priority = (RequestPriority)dto.Priority,
                Notes = dto.Notes
            };

            if (!_requestService.Update(id, entity))
            {
                return NotFound();
            }

            return Ok();
        }

        [HttpPut]
        [Route("{id:int}/status")]
        public IHttpActionResult UpdateStatus(int id, MaintenanceRequestStatusUpdateDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Status payload is required.");
            }

            var updated = _requestService.UpdateStatus(id, (RequestStatus)dto.Status);
            if (!updated)
            {
                return BadRequest("Invalid status transition or request not found.");
            }

            return Ok();
        }

        [HttpPut]
        [Route("{id:int}/assign")]
        public IHttpActionResult Assign(int id, RequestAssignmentDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Assignment payload is required.");
            }

            if (!_requestService.Assign(id, dto.AssignedToId))
            {
                return NotFound();
            }

            return Ok();
        }

        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Delete(int id)
        {
            if (!_requestService.Delete(id))
            {
                return NotFound();
            }

            return Ok();
        }

        private static MaintenanceRequestDto MapToDto(MaintenanceRequest request)
        {
            return new MaintenanceRequestDto
            {
                Id = request.Id,
                Title = request.Title,
                Description = request.Description,
                Status = (int)request.Status,
                StatusName = request.Status.ToString(),
                Priority = (int)request.Priority,
                PriorityName = request.Priority.ToString(),
                TenantId = request.TenantId,
                TenantName = request.Tenant != null ? request.Tenant.FirstName + " " + request.Tenant.LastName : null,
                PropertyId = request.PropertyId,
                PropertyName = request.Property != null ? request.Property.Name : null,
                AssignedToId = request.AssignedToId,
                CreatedDate = request.CreatedDate,
                UpdatedDate = request.UpdatedDate,
                CompletedDate = request.CompletedDate,
                Notes = request.Notes,
                Attachments = request.Attachments == null
                    ? null
                    : request.Attachments.Select(a => new AttachmentDto
                    {
                        Id = a.Id,
                        FileName = a.FileName,
                        ContentType = a.ContentType,
                        FileSize = a.FileSize,
                        MaintenanceRequestId = a.MaintenanceRequestId,
                        UploadedDate = a.UploadedDate,
                        UploadedById = a.UploadedById
                    }).ToList(),
                StatusHistory = request.StatusHistories == null
                    ? null
                    : request.StatusHistories
                        .OrderByDescending(h => h.ChangedOn)
                        .Select(h => new StatusHistoryDto
                        {
                            Id = h.Id,
                            FromStatus = h.FromStatus.ToString(),
                            NewStatus = h.ToStatus.ToString(),
                            ChangedBy = h.ChangedBy,
                            ChangedOn = h.ChangedOn
                        }).ToList()
            };
        }
    }
}
