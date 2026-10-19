using BeautyStudio.Api.Services;
using BeautyStudio.Api.Contracts.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace BeautyStudio.Api.Controllers;
[ApiController, Route("api/notifications"), Authorize]
public sealed class NotificationsController(NotificationService service, ListQueryService queries) : ControllerBase
{
    [HttpGet] public Task<BeautyStudio.Api.Contracts.Common.PagedResponse<NotificationResponse>> Get([FromQuery] BeautyStudio.Api.Contracts.Common.ListQuery q, CancellationToken token) => queries.NotificationsAsync(q, token);
    [HttpPost("{id:guid}/read")] public async Task<IActionResult> Read(Guid id, CancellationToken token) { await service.MarkReadAsync(id, token); return NoContent(); }
    [HttpPost("read-all")] public async Task<IActionResult> ReadAll(CancellationToken token) { await service.MarkAllReadAsync(token); return NoContent(); }
}
