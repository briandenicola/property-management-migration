# Argyle — History

## Learnings

- Project: Property management app for maintenance requests
- Legacy frontend: AngularJS 1.x with Bootstrap 3, must look authentically ~2015-era
- Features: maintenance request form with file upload (images/docs), request listing, detail view
- User: Brian
- 2026-04-29T20:40:56.058Z: Implemented full legacy AngularJS frontend shell at `src/PropertyManager.Web/app/` with ui-router state map and controller-driven views for dashboard, auth, maintenance, properties, and tenants.
- 2026-04-29T20:40:56.058Z: Standardized API integration through `$http` services (`maintenanceRequestService`, `propertyService`, `tenantService`, `authService`) and jQuery hybrid multipart upload service (`fileUploadService`) matching legacy architecture patterns.
- 2026-04-29T20:40:56.058Z: Added legacy UI structure and styling in `index.html`, `views/*.html`, and `css/site.css` using Bootstrap 3.3.7 panels/wells/glyphicons, manual script loading, drag-drop plus classic file input, image preview, and upload progress.
- 2026-04-29T20:40:56.058Z: Chose cookie-compatible auth guard behavior that checks `/api/account/userinfo` on route transitions to support forms-auth sessions without requiring token-only flows.

### 2026-04-29T20:55:27Z — Scribe: Decisions Archived
- Frontend structure decision merged and consolidated in decisions.md
- Orchestration log created at `.squad/orchestration-log/2026-04-29T20-40-56-argyle.md`
- All team architecture decisions now unified and available for reference
