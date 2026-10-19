using BeautyStudio.Api.Contracts.Reviews;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/admin/reviews")]
[Authorize(Roles = "Admin,Owner")]
public sealed class AdminReviewsController(ListQueryService queries) : ControllerBase
{
    [HttpGet("summary")]
    public Task<BeautyStudio.Api.Contracts.Common.PagedResponse<ServiceReviewSummaryResponse>> Summary([FromQuery] BeautyStudio.Api.Contracts.Common.ListQuery q, CancellationToken cancellationToken) => queries.ReviewSummaryAsync(q, cancellationToken);
}
