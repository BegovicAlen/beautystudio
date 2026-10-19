using BeautyStudio.Api.Domain;
namespace BeautyStudio.Api.Contracts.Activities;
public sealed record RecordActivityRequest(UserActivityType Type, int? ServiceId, int? CategoryId, Guid? BlogPostId, Guid? GalleryItemId);
