using BeautyStudio.Api.Contracts.Auth;
namespace BeautyStudio.Api.Services;
public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken);
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken);
    Task LogoutAsync(CancellationToken ct);
    Task<RecoveryCodeResponse> ResetAsync(ResetPasswordRequest request, CancellationToken ct);
    Task<RecoveryCodeResponse> RecoveryCodeAsync(RecoveryCodeRequest request, CancellationToken ct);
}
