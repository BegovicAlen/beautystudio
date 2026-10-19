namespace BeautyStudio.Api.Contracts.Content;

public sealed record GalleryItemResponse(Guid Id, string Title, string ImageUrl, string Category, DateTime CreatedAtUtc, int CategoryId = 0, string Description = "");
