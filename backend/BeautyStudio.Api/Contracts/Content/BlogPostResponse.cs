namespace BeautyStudio.Api.Contracts.Content;

public sealed record BlogPostResponse(Guid Id, string Title, string Content, string? ImageUrl, DateTime PublishedAtUtc, int CategoryId = 0, string CategoryName = "");
