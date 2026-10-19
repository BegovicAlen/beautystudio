using BeautyStudio.Api.Contracts.Administration;
using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
public sealed class ReferenceController(ReferenceService service) : ControllerBase
{
    [AllowAnonymous, HttpGet("api/reference/{kind}")]
    public Task<PagedResponse<ReferenceResponse>> Public(string kind, [FromQuery] ListQuery q, CancellationToken ct) { q.Active = true; return service.GetAsync(kind, q, ct); }
    [Authorize(Roles = "Admin"), HttpGet("api/admin/reference/{kind}")]
    public Task<PagedResponse<ReferenceResponse>> Get(string kind, [FromQuery] ListQuery q, CancellationToken ct) => service.GetAsync(kind, q, ct);
    [Authorize(Roles = "Admin"), HttpPost("api/admin/reference/{kind}")]
    public Task<ReferenceResponse> Create(string kind, UpsertReferenceRequest request, CancellationToken ct) => service.SaveAsync(kind, null, request, ct);
    [Authorize(Roles = "Admin"), HttpPut("api/admin/reference/{kind}/{id:int}")]
    public Task<ReferenceResponse> Update(string kind, int id, UpsertReferenceRequest request, CancellationToken ct) => service.SaveAsync(kind, id, request, ct);
}
