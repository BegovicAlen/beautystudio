namespace BeautyStudio.Api.Domain;

public sealed class AppUser
{
    public Guid Id { get; set; }
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
    public required string Username { get; set; }
    public required string Email { get; set; }
    public required string PasswordHash { get; set; }
    public UserRole Role { get; set; } = UserRole.Client;
    public bool IsActive { get; set; } = true;
    public string? ProfileImageUrl { get; set; }
    public bool NotificationsEnabled { get; set; } = true;
    public int? CityId { get; set; }
    public City? City { get; set; }
    public string? RecoveryCodeHash { get; set; }
    public DateTime? RecoveryCodeExpiresAtUtc { get; set; }
    public int TokenVersion { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
}

public enum UserRole { Client, Admin, Owner }
