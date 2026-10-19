using BeautyStudio.Api.Domain;

namespace BeautyStudio.Api.Contracts.Reservations;

public sealed record ReservationHistoryResponse(Guid Id, ReservationStatus? FromStatus, ReservationStatus ToStatus, string Reason, DateTime ChangedAtUtc, string ChangedByName);
