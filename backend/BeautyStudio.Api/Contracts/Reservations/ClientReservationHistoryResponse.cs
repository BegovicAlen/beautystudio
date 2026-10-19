namespace BeautyStudio.Api.Contracts.Reservations;

public sealed record ClientReservationHistoryResponse(
    Guid ClientId,
    string ClientName,
    string ClientEmail,
    IReadOnlyList<StaffReservationResponse> Reservations, int Total = 0, int Page = 1, int PageSize = 20);
