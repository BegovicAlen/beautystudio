using BeautyStudio.Api.Domain;
namespace BeautyStudio.Api.Contracts.Reservations;
public sealed record ReservationResponse(Guid Id, string ServiceName, DateTime StartAtUtc, DateTime EndAtUtc, ReservationPaymentMethod PaymentMethod, ReservationStatus Status, string? CancellationReason, string PaymentStatus = "Unpaid", bool IsPaid = false, bool HasReview = false, decimal TotalAmount = 0, decimal PaidAmount = 0, decimal RemainingAmount = 0, string Currency = "bam", string StatusDisplayName = "");
