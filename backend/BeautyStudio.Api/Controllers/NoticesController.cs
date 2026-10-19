using BeautyStudio.Api.Contracts.Notifications;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;
[ApiController, Route("api/admin/notices"), Authorize(Roles = "Admin")]
public sealed class NoticesController(NotificationService service) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Send(SendNoticeRequest request, CancellationToken ct) { await service.SendAsync(request, ct); return NoContent(); }
}
