using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Contracts.Auth;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace BeautyStudio.Api.Services;

public sealed class AuthService(BeautyStudioDbContext db, AppConfiguration config, IHttpContextAccessor http, NotificationComposer notifications) : IAuthService
{
    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken ct)
    {
        var first = InputValidation.Text(request.FirstName, "Ime", 100);
        var last = InputValidation.Text(request.LastName, "Prezime", 100);
        var username = InputValidation.Text(request.Username, "Korisničko ime", 50).ToLowerInvariant();
        if (username.Length < 3 || username.Any(c => !char.IsLetterOrDigit(c) && c is not '_' and not '.' and not '-')) throw new BusinessException("Korisničko ime mora imati 3–50 slova, cifara, tačaka, crtica ili donjih crtica.");
        var email = InputValidation.Email(request.Email);
        InputValidation.Password(request.Password);
        await using var tx = await BookingLock.BeginAsync(db, ct);
        if (await db.Users.AnyAsync(x => x.Email == email, ct)) throw new BusinessException("Korisnik s tim emailom već postoji.");
        if (await db.Users.AnyAsync(x => x.Username == username, ct)) throw new BusinessException("Korisničko ime je zauzeto.");
        var user = new AppUser { Id = Guid.NewGuid(), FirstName = first, LastName = last, Username = username, Email = email, PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password), Role = UserRole.Client };
        var recovery = AssignRecoveryCode(user);
        db.Users.Add(user);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return CreateToken(user) with { RecoveryCode = recovery.RecoveryCode };
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken ct)
    {
        var identifier = request.UsernameOrEmail.Trim().ToLowerInvariant();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == identifier || x.Username == identifier, ct);
        if (user == null || !user.IsActive || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash)) throw new BusinessException("Korisničko ime/email ili lozinka nisu ispravni.");
        return CreateToken(user);
    }

    public async Task LogoutAsync(CancellationToken ct)
    {
        var principal = http.HttpContext!.User;
        var jti = principal.FindFirstValue(JwtRegisteredClaimNames.Jti);
        if (jti == null || await db.RevokedTokens.AnyAsync(x => x.Id == jti, ct)) return;
        db.RevokedTokens.Add(new RevokedToken { Id = jti, UserId = Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!), ExpiresAtUtc = DateTimeOffset.FromUnixTimeSeconds(long.Parse(principal.FindFirstValue("exp")!)).UtcDateTime });
        await db.SaveChangesAsync(ct);
    }

    public async Task<RecoveryCodeResponse> ResetAsync(ResetPasswordRequest request, CancellationToken ct)
    {
        InputValidation.Password(request.NewPassword);
        await using var tx = await BookingLock.BeginAsync(db, ct);
        var value = request.UsernameOrEmail.Trim().ToLowerInvariant();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Username == value || x.Email == value, ct);
        var supplied = HashRecoveryCode(request.RecoveryCode);
        if (user == null || !user.IsActive || user.RecoveryCodeHash == null || user.RecoveryCodeExpiresAtUtc <= DateTime.UtcNow || !CryptographicOperations.FixedTimeEquals(Convert.FromHexString(user.RecoveryCodeHash), Convert.FromHexString(supplied)))
            throw new BusinessException("Nalog ili kod za oporavak nije ispravan, odnosno kod je istekao.");
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        user.TokenVersion++;
        var replacement = AssignRecoveryCode(user);
        await notifications.AddAsync(user.Id, "AccountSecurity", "Lozinka promijenjena", "Lozinka je obnovljena pomoću jednokratnog koda za oporavak. Prethodne sesije su odjavljene.", ct);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return replacement;
    }

    public async Task<RecoveryCodeResponse> RecoveryCodeAsync(RecoveryCodeRequest request, CancellationToken ct)
    {
        var id = Guid.Parse(http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var user = await db.Users.SingleAsync(x => x.Id == id, ct);
        if (!BCrypt.Net.BCrypt.Verify(request.CurrentPassword, user.PasswordHash)) throw new BusinessException("Trenutna lozinka nije ispravna.");
        var result = AssignRecoveryCode(user);
        await db.SaveChangesAsync(ct);
        return result;
    }

    public static string HashRecoveryCode(string? code) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes((code ?? "").Replace(" ", "").Replace("-", "").Trim().ToUpperInvariant())));
    private static RecoveryCodeResponse AssignRecoveryCode(AppUser user)
    {
        var code = Convert.ToHexString(RandomNumberGenerator.GetBytes(24));
        user.RecoveryCodeHash = HashRecoveryCode(code);
        user.RecoveryCodeExpiresAtUtc = DateTime.UtcNow.AddYears(1);
        return new RecoveryCodeResponse(code, user.RecoveryCodeExpiresAtUtc.Value);
    }

    private AuthResponse CreateToken(AppUser user)
    {
        var expires = DateTime.UtcNow.AddHours(8);
        var claims = new[] { new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()), new Claim(ClaimTypes.Email, user.Email), new Claim(ClaimTypes.Role, user.Role.ToString()), new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")), new Claim("token_version", user.TokenVersion.ToString()) };
        var token = new JwtSecurityToken(config.JwtIssuer, config.JwtAudience, claims, expires: expires, signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config.JwtKey)), SecurityAlgorithms.HmacSha256));
        return new AuthResponse(new JwtSecurityTokenHandler().WriteToken(token), expires, user.Role.ToString());
    }
}
