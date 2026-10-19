namespace BeautyStudio.Api.Domain;
public sealed class Payment
{
    public Guid Id { get; set; }
    public Guid ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;
    public string? StripeCheckoutSessionId { get; set; }
    public string? StripePaymentIntentId { get; set; }
    public string? StripeRefundId { get; set; }
    public string? ReceiptUrl { get; set; }
    public string Provider { get; set; } = "Stripe";
    public decimal Amount { get; set; }
    public decimal RefundedAmount { get; set; }
    public string Currency { get; set; } = "bam";
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? PaidAtUtc { get; set; }
    public DateTime? RefundedAtUtc { get; set; }
    public ICollection<PaymentTransaction> Transactions { get; set; } = new List<PaymentTransaction>();
}
public enum PaymentStatus { Pending, Paid, Failed, Expired, RefundPending, Refunded, PartiallyRefunded }
