namespace BeautyStudio.Api.Contracts.Content;

public sealed record UpsertGalleryItemRequest(string Title, string ImageUrl, int CategoryId, bool IsActive, string? Description = null);
