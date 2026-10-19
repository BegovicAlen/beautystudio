using BeautyStudio.Api.Contracts.Dashboard;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/dashboard")]
[Authorize(Roles = "Admin,Owner")]
public sealed class DashboardController(DashboardService service) : ControllerBase
{
    [HttpGet]
    public Task<DashboardResponse> Get(CancellationToken cancellationToken) => service.GetAsync(cancellationToken);
}
