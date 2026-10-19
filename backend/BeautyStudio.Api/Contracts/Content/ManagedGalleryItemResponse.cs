namespace BeautyStudio.Api.Contracts.Content;

public sealed record ManagedGalleryItemResponse(Guid Id, string Title, string ImageUrl, string Category, bool IsActive, DateTime CreatedAtUtc, int CategoryId = 0, string Description = "");
