using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace BeautyStudio.Api.Controllers;
[ApiController, Route("api/services")]
public sealed class ServicesController(ListQueryService queries) : ControllerBase
{
    [AllowAnonymous, HttpGet]
    public Task<BeautyStudio.Api.Contracts.Common.PagedResponse<BeautyStudio.Api.Contracts.Administration.ManagedServiceResponse>> Get([FromQuery] BeautyStudio.Api.Contracts.Common.ListQuery q, CancellationToken cancellationToken) => queries.ServicesAsync(q, false, cancellationToken);
}
