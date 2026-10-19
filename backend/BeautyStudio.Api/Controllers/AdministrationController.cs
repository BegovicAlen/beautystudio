using BeautyStudio.Api.Contracts.Administration;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BeautyStudio.Api.Contracts.Common;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public sealed class AdministrationController(AdministrationService service, ListQueryService queries) : ControllerBase
{
    [HttpGet("services")] public Task<PagedResponse<ManagedServiceResponse>> Services([FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.ServicesAsync(q, true, cancellationToken);
    [HttpPost("services")] public Task<ManagedServiceResponse> CreateService(UpsertServiceRequest request, CancellationToken cancellationToken) => service.CreateServiceAsync(request, cancellationToken);
    [HttpPut("services/{id:int}")] public Task<ManagedServiceResponse> UpdateService(int id, UpsertServiceRequest request, CancellationToken cancellationToken) => service.UpdateServiceAsync(id, request, cancellationToken);
    [HttpGet("categories")] public Task<PagedResponse<ManagedCategoryResponse>> Categories([FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.CategoriesAsync(q, cancellationToken);
    [HttpPost("categories")] public Task<ManagedCategoryResponse> CreateCategory(UpsertCategoryRequest request, CancellationToken cancellationToken) => service.CreateCategoryAsync(request, cancellationToken);
    [HttpPut("categories/{id:int}")] public Task<ManagedCategoryResponse> UpdateCategory(int id, UpsertCategoryRequest request, CancellationToken cancellationToken) => service.UpdateCategoryAsync(id, request, cancellationToken);
    [HttpGet("users")] public Task<PagedResponse<ManagedUserResponse>> Users([FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.UsersAsync(q, cancellationToken);
    [HttpPost("users")] public Task<ManagedUserResponse> CreateUser(CreateUserRequest request, CancellationToken cancellationToken) => service.CreateUserAsync(request, cancellationToken);
    [HttpPut("users/{id:guid}")] public Task<ManagedUserResponse> UpdateUser(Guid id, UpdateUserRequest request, CancellationToken cancellationToken) => service.UpdateUserAsync(id, request, cancellationToken);
}
