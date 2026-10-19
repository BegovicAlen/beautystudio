namespace BeautyStudio.Api.Contracts.Recommendations;

public sealed record RecommendationResponse(int ServiceId, string Name, decimal Price, string Reason);
public sealed record ContentRecommendationsResponse(IReadOnlyList<CategoryRecommendationResponse> Categories, IReadOnlyList<BlogRecommendationResponse> BlogPosts);
public sealed record CategoryRecommendationResponse(int CategoryId, string Name, string Reason);
public sealed record BlogRecommendationResponse(Guid BlogPostId, string Title, string? ImageUrl, string Reason);
