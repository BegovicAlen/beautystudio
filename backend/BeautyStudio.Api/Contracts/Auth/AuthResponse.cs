namespace BeautyStudio.Api.Contracts.Auth;
public sealed record AuthResponse(string Token, DateTime ExpiresAtUtc, string Role, string? RecoveryCode = null);
