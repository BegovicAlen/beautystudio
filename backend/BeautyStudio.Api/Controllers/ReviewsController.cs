using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Contracts.Reviews;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/reviews")]
public sealed class ReviewsController(ReviewService service) : ControllerBase
{
    [AllowAnonymous]
    [HttpGet]
    public Task<PagedResponse<ReviewResponse>> Get([FromQuery] int serviceId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default) => service.GetForServiceAsync(serviceId, page, pageSize, cancellationToken);

    [Authorize]
    [HttpPost]
    public Task<ReviewResponse> Create(CreateReviewRequest request, CancellationToken cancellationToken) => service.CreateAsync(request, cancellationToken);
}
