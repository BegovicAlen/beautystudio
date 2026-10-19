using BeautyStudio.Api.Contracts.Recommendations;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController, Route("api/recommendations"), Authorize]
public sealed class RecommendationsController(RecommendationService service) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<RecommendationResponse>> Get(CancellationToken cancellationToken) => service.GetForCurrentUserAsync(cancellationToken);
    [HttpGet("content")]
    public Task<ContentRecommendationsResponse> Content(CancellationToken cancellationToken) => service.GetContentForCurrentUserAsync(cancellationToken);
}
