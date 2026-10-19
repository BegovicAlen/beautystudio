using BeautyStudio.Api.Contracts.Activities;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;
[ApiController, Route("api/activities"), Authorize]
public sealed class ActivitiesController(ActivityService service) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Record(RecordActivityRequest request, CancellationToken cancellationToken) { await service.RecordAsync(request, cancellationToken); return NoContent(); }
}
