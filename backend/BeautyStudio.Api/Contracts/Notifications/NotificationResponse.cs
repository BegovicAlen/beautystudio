namespace BeautyStudio.Api.Contracts.Notifications;

public sealed record NotificationResponse(Guid Id, string Title, string Message, bool IsRead, DateTime CreatedAtUtc);
