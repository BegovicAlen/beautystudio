namespace BeautyStudio.Api.Contracts.Content;

public sealed record UpsertBlogPostRequest(string Title, string Content, string? ImageUrl, bool IsPublished, int CategoryId);
