namespace BeautyStudio.Api.Contracts.Content;

public sealed record ManagedBlogPostResponse(Guid Id, string Title, string Content, string? ImageUrl, bool IsPublished, DateTime PublishedAtUtc, int CategoryId = 0, string CategoryName = "");
