namespace BeautyStudio.Api.Contracts.Profile;

public sealed record ProfileResponse(string FirstName, string LastName, string Username, string Email, string? ProfileImageUrl, bool NotificationsEnabled, int? CityId = null, string? CityName = null);
public sealed record UpdateProfileRequest(string FirstName, string LastName, string Email, string? ProfileImageUrl, bool NotificationsEnabled, string? CurrentPassword, string? NewPassword, int? CityId = null);
