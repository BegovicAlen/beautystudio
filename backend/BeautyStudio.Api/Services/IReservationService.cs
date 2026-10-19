using BeautyStudio.Api.Contracts.Reservations;
namespace BeautyStudio.Api.Services;
public interface IReservationService
{
    Task<AvailabilityResponse> GetAvailabilityAsync(int serviceId, DateOnly date, CancellationToken cancellationToken);
    Task<ReservationResponse> CreateAsync(CreateReservationRequest request, CancellationToken cancellationToken);
    Task<ClientReservationHistoryResponse> GetClientHistoryAsync(Guid clientId, CancellationToken cancellationToken, BeautyStudio.Api.Contracts.Common.ListQuery? query = null);
    Task<ReservationResponse> CancelMineAsync(Guid id, string reason, CancellationToken cancellationToken);
    Task<ReservationResponse> ChangeStatusAsync(Guid id, ChangeReservationStatusRequest request, CancellationToken cancellationToken);
    Task<int> ProcessExpiredReservationsAsync(CancellationToken cancellationToken);
}
