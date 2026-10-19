namespace BeautyStudio.Api.Contracts.Reviews;

public sealed record ServiceReviewSummaryResponse(int ServiceId, string ServiceName, int ReviewCount, double AverageRating);
