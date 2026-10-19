namespace BeautyStudio.Api.Domain;

public sealed class Review
{
    public Guid Id { get; set; }
    public Guid ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public int ServiceId { get; set; }
    public BeautyService Service { get; set; } = null!;
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
