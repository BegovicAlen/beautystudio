namespace BeautyStudio.Api.Domain;
public sealed class UserActivity { public Guid Id { get; set; } public Guid UserId { get; set; } public AppUser User { get; set; } = null!; public UserActivityType Type { get; set; } public int? ServiceId { get; set; } public Guid? BlogPostId { get; set; } public Guid? GalleryItemId { get; set; } public int? CategoryId { get; set; } public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow; }
public enum UserActivityType { ServiceViewed, ServiceReserved, CategoryViewed, BlogViewed, GalleryViewed }
