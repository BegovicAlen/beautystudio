namespace BeautyStudio.Api.Domain;

public sealed class City
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public bool IsActive { get; set; } = true;
}

public sealed class ReservationStatusDefinition
{
    public int Id { get; set; }
    public ReservationStatus Code { get; set; }
    public required string Name { get; set; }
    public bool IsActive { get; set; } = true;
}

public sealed class NotificationType
{
    public int Id { get; set; }
    public required string Code { get; set; }
    public required string Name { get; set; }
    public bool IsActive { get; set; } = true;
}

public sealed class NotificationOutbox
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public int NotificationTypeId { get; set; }
    public NotificationType NotificationType { get; set; } = null!;
    public required string Title { get; set; }
    public required string Message { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? PublishedAtUtc { get; set; }
}

public sealed class PaymentTransaction
{
    public Guid Id { get; set; }
    public Guid PaymentId { get; set; }
    public Payment Payment { get; set; } = null!;
    public required string Kind { get; set; }
    public required string ProviderId { get; set; }
    public decimal Amount { get; set; }
    public DateTime OccurredAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class RevokedToken
{
    public string Id { get; set; } = "";
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public DateTime ExpiresAtUtc { get; set; }
}
