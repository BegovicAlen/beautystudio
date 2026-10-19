namespace BeautyStudio.Api.Domain;
public sealed class BlogPost { public Guid Id { get; set; } public required string Title { get; set; } public required string Content { get; set; } public string? ImageUrl { get; set; } public int CategoryId { get; set; } public ServiceCategory Category { get; set; } = null!; public bool IsPublished { get; set; } public DateTime PublishedAtUtc { get; set; } }
