namespace BeautyStudio.Api.Contracts.Reviews;

public sealed record ReviewResponse(Guid Id, int ServiceId, string ClientName, int Rating, string? Comment, DateTime CreatedAtUtc);
