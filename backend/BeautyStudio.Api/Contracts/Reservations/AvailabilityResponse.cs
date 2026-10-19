namespace BeautyStudio.Api.Contracts.Reservations;
public sealed record AvailabilityResponse(IReadOnlyList<DateTime> AvailableStartAtUtc);
