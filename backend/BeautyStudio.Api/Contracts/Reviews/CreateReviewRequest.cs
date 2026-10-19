namespace BeautyStudio.Api.Contracts.Reviews;

public sealed record CreateReviewRequest(Guid ReservationId, int Rating, string? Comment);
