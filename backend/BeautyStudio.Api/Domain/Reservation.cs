namespace BeautyStudio.Api.Domain;

public sealed class Reservation
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public int ServiceId { get; set; }
    public BeautyService Service { get; set; } = null!;
    public DateTime StartAtUtc { get; set; }
    public DateTime EndAtUtc { get; set; }
    public ReservationPaymentMethod PaymentMethod { get; set; } = ReservationPaymentMethod.OnSite;
    public ReservationStatus Status { get; set; } = ReservationStatus.Pending;
    public int StatusDefinitionId { get; set; } = 1;
    public ReservationStatusDefinition StatusDefinition { get; set; } = null!;
    public decimal TotalAmount { get; set; }
    public int DepositPercent { get; set; } = 100;
    public string Currency { get; set; } = "bam";
    public string? CancellationReason { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public enum ReservationStatus { Pending, Confirmed, Cancelled, Completed }
public enum ReservationPaymentMethod { OnSite, Card }
