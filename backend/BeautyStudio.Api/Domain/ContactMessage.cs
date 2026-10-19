namespace BeautyStudio.Api.Domain;

public sealed class ContactMessage
{
    public Guid Id { get; set; }
    public Guid? UserId { get; set; }
    public AppUser? User { get; set; }
    public required string FullName { get; set; }
    public required string Email { get; set; }
    public required string Phone { get; set; }
    public required string Message { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
