namespace BeautyStudio.Api.Contracts.Notifications;
public sealed record SendNoticeRequest(Guid RecipientId, int NotificationTypeId, string Title, string Message);
