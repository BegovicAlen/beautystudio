namespace BeautyStudio.Api.Domain;

public sealed class ReservationStatusHistory
{
    public Guid Id { get; set; }
    public Guid ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;
    public ReservationStatus? FromStatus { get; set; }
    public ReservationStatus ToStatus { get; set; }
    public Guid? ChangedByUserId { get; set; }
    public AppUser? ChangedBy { get; set; }
    public required string Reason { get; set; }
    public DateTime ChangedAtUtc { get; set; } = DateTime.UtcNow;
}
