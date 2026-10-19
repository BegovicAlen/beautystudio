using BeautyStudio.Api.Contracts.Auth;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(IAuthService service) : ControllerBase
{
    [AllowAnonymous]
    [HttpPost("register")]
    [EnableRateLimiting("auth")]
    public Task<AuthResponse> Register(RegisterRequest request, CancellationToken cancellationToken) => service.RegisterAsync(request, cancellationToken);

    [AllowAnonymous]
    [HttpPost("login")]
    [EnableRateLimiting("auth")]
    public Task<AuthResponse> Login(LoginRequest request, CancellationToken cancellationToken) => service.LoginAsync(request, cancellationToken);

    [Authorize, HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken ct) { await service.LogoutAsync(ct); return NoContent(); }

    [AllowAnonymous, HttpPost("reset-password"), EnableRateLimiting("auth")]
    public Task<RecoveryCodeResponse> Reset(ResetPasswordRequest request, CancellationToken ct) => service.ResetAsync(request, ct);

    [Authorize, HttpPost("recovery-code"), EnableRateLimiting("auth")]
    public Task<RecoveryCodeResponse> RecoveryCode(RecoveryCodeRequest request, CancellationToken ct) => service.RecoveryCodeAsync(request, ct);
}
