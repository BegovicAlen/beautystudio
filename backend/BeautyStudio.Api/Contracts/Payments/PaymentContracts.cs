namespace BeautyStudio.Api.Contracts.Payments;
public sealed record CheckoutResponse(string Url, string Status);
public sealed record CheckoutRequest(bool Mobile = false);
public sealed record PaymentResponse(Guid Id, Guid ReservationId, string ClientName, string ServiceName, DateTime AppointmentStartAtUtc, decimal Amount, string Currency, string Status, DateTime CreatedAtUtc, DateTime? PaidAtUtc, string Provider = "Stripe", decimal RefundedAmount = 0, DateTime? RefundedAtUtc = null, string? ReceiptUrl = null, decimal TotalAmount = 0);
