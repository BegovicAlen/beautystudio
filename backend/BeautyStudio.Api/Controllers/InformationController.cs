using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Contracts.Information;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;
[ApiController, Route("api/information")]
public sealed class InformationController(InformationService service, ListQueryService queries) : ControllerBase
{
    [AllowAnonymous, HttpGet("faq")] public Task<PagedResponse<FaqResponse>> Faq([FromQuery] ListQuery q, CancellationToken ct) => queries.FaqAsync(q, false, ct);
    [AllowAnonymous, HttpGet("about")] public Task<AboutResponse> About(CancellationToken ct) => service.AboutAsync(ct);
    [Authorize(Roles = "Admin,Owner"), HttpGet("admin/faq")] public Task<PagedResponse<FaqResponse>> AdminFaq([FromQuery] ListQuery q, CancellationToken ct) => queries.FaqAsync(q, true, ct);
    [Authorize(Roles = "Admin,Owner"), HttpPost("admin/faq")] public Task<FaqResponse> Add(UpsertFaqRequest r, CancellationToken ct) => service.SaveFaqAsync(null, r, ct);
    [Authorize(Roles = "Admin,Owner"), HttpPut("admin/faq/{id:guid}")] public Task<FaqResponse> Edit(Guid id, UpsertFaqRequest r, CancellationToken ct) => service.SaveFaqAsync(id, r, ct);
    [Authorize(Roles = "Admin,Owner"), HttpPut("admin/about")] public Task<AboutResponse> SaveAbout(UpsertAboutRequest r, CancellationToken ct) => service.SaveAboutAsync(r, ct);
}
