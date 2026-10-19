using BeautyStudio.Api.Contracts.Reservations;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BeautyStudio.Api.Contracts.Common;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/reservations")]
[Authorize]
public sealed class ReservationsController(IReservationService service, ListQueryService queries) : ControllerBase
{
    [HttpGet("availability")]
    public Task<AvailabilityResponse> Availability([FromQuery] int serviceId, [FromQuery] DateOnly date, CancellationToken cancellationToken) => service.GetAvailabilityAsync(serviceId, date, cancellationToken);
    [HttpPost]
    public Task<ReservationResponse> Create(CreateReservationRequest request, CancellationToken cancellationToken) => service.CreateAsync(request, cancellationToken);

    [HttpGet("mine")]
    public Task<PagedResponse<ReservationResponse>> Mine([FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.MineAsync(q, cancellationToken);

    [HttpGet]
    [Authorize(Roles = "Admin,Owner")]
    public Task<PagedResponse<StaffReservationResponse>> Management([FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.ReservationsAsync(q, cancellationToken);

    [HttpGet("clients/{clientId:guid}/history")]
    [Authorize(Roles = "Admin,Owner")]
    public Task<ClientReservationHistoryResponse> ClientHistory(Guid clientId, [FromQuery] ListQuery q, CancellationToken cancellationToken) => service.GetClientHistoryAsync(clientId, cancellationToken, q);

    [HttpGet("{id:guid}/history")]
    [Authorize(Roles = "Admin,Owner")]
    public Task<PagedResponse<ReservationHistoryResponse>> History(Guid id, [FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.HistoryAsync(id, q, cancellationToken);

    [HttpPost("{id:guid}/cancel")]
    public Task<ReservationResponse> Cancel(Guid id, ChangeReservationStatusRequest request, CancellationToken cancellationToken) => service.CancelMineAsync(id, request.Reason, cancellationToken);

    [HttpPost("{id:guid}/status")]
    [Authorize(Roles = "Admin,Owner")]
    public Task<ReservationResponse> ChangeStatus(Guid id, ChangeReservationStatusRequest request, CancellationToken cancellationToken) => service.ChangeStatusAsync(id, request, cancellationToken);
}
