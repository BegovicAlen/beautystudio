namespace BeautyStudio.Api.Contracts.Dashboard;

public sealed record DashboardResponse(
    int TotalReservations,
    int ActiveReservations,
    int ActiveClients,
    decimal CompletedRevenue,
    string? MostPopularService,
    IReadOnlyList<DashboardReservationResponse> RecentReservations,
    IReadOnlyList<PopularServiceResponse> PopularServices);

public sealed record DashboardReservationResponse(Guid Id, string ClientName, string ServiceName, DateTime StartAtUtc, string Status);

public sealed record PopularServiceResponse(int ServiceId, string Name, int ReservationCount, int CompletedCount);
