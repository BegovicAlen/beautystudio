namespace BeautyStudio.Api.Contracts.Auth;
public sealed record ResetPasswordRequest(string UsernameOrEmail, string RecoveryCode, string NewPassword);
public sealed record RecoveryCodeRequest(string CurrentPassword);
public sealed record RecoveryCodeResponse(string RecoveryCode, DateTime ExpiresAtUtc);
