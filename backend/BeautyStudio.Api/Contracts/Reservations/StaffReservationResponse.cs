using BeautyStudio.Api.Domain;

namespace BeautyStudio.Api.Contracts.Reservations;

public sealed record StaffReservationResponse(
    Guid Id,
    Guid ClientId,
    string ClientName,
    string ClientEmail,
    string ServiceName,
    DateTime StartAtUtc,
    DateTime EndAtUtc,
    ReservationPaymentMethod PaymentMethod,
    ReservationStatus Status,
    string? CancellationReason,
    string PaymentStatus,
    decimal? PaymentAmount,
    string? PaymentCurrency,
    DateTime? PaidAtUtc, string StatusDisplayName = "");
