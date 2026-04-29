using System;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using System.Web.Http;
using Microsoft.AspNet.Identity;
using PropertyManager.Core.Interfaces;
using PropertyManager.Web.Models;

namespace PropertyManager.Web.Controllers
{
    [RoutePrefix("api")]
    public class AttachmentsController : ApiController
    {
        private readonly IAttachmentService _attachmentService;

        public AttachmentsController()
        {
            _attachmentService = LegacyServiceLocator.GetAttachmentService();
        }

        [HttpGet]
        [Route("maintenancerequests/{id:int}/attachments")]
        public IHttpActionResult GetByRequest(int id)
        {
            var attachments = _attachmentService.GetByMaintenanceRequestId(id)
                .Select(MapToDto)
                .ToList();
            return Ok(attachments);
        }

        [HttpPost]
        [Route("maintenancerequests/{id:int}/attachments")]
        public async Task<IHttpActionResult> Upload(int id)
        {
            if (!Request.Content.IsMimeMultipartContent())
            {
                return BadRequest("Expected multipart/form-data.");
            }

            var provider = new MultipartMemoryStreamProvider();
            await Request.Content.ReadAsMultipartAsync(provider);

            var file = provider.Contents.FirstOrDefault();
            if (file == null)
            {
                return BadRequest("No file uploaded.");
            }

            var fileName = file.Headers.ContentDisposition.FileName == null
                ? "upload.bin"
                : file.Headers.ContentDisposition.FileName.Trim('"');
            var extension = Path.GetExtension(fileName) ?? string.Empty;
            var allowed = (ConfigurationManager.AppSettings["AllowedFileExtensions"] ?? ".jpg,.jpeg,.png,.gif,.pdf,.doc,.docx")
                .Split(',')
                .Select(e => e.Trim().ToLowerInvariant())
                .ToArray();

            if (!allowed.Contains(extension.ToLowerInvariant()))
            {
                return BadRequest("File type is not allowed.");
            }

            var fileBytes = await file.ReadAsByteArrayAsync();
            var maxSize = 10485760;
            int.TryParse(ConfigurationManager.AppSettings["MaxFileUploadSize"], out maxSize);

            if (fileBytes.Length > maxSize)
            {
                return BadRequest("File exceeds the maximum 10MB limit.");
            }

            var attachment = _attachmentService.SaveUpload(
                id,
                fileName,
                file.Headers.ContentType == null ? "application/octet-stream" : file.Headers.ContentType.MediaType,
                fileBytes,
                User.Identity.GetUserId());

            return Ok(MapToDto(attachment));
        }

        [HttpGet]
        [Route("attachments/{id:int}")]
        public IHttpActionResult Download(int id)
        {
            var attachment = _attachmentService.GetById(id);
            if (attachment == null)
            {
                return NotFound();
            }

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

        [HttpDelete]
        [Route("attachments/{id:int}")]
        public IHttpActionResult Delete(int id)
        {
            if (!_attachmentService.Delete(id))
            {
                return NotFound();
            }

            return Ok();
        }

        private static AttachmentDto MapToDto(PropertyManager.Data.Entities.Attachment attachment)
        {
            return new AttachmentDto
            {
                Id = attachment.Id,
                FileName = attachment.FileName,
                ContentType = attachment.ContentType,
                FileSize = attachment.FileSize,
                MaintenanceRequestId = attachment.MaintenanceRequestId,
                UploadedDate = attachment.UploadedDate,
                UploadedById = attachment.UploadedById
            };
        }
    }
}
