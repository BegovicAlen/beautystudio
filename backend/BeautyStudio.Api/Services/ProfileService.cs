using System.Security.Claims;
using BeautyStudio.Api.Contracts.Profile;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class ProfileService(BeautyStudioDbContext db, IHttpContextAccessor accessor)
{
    public async Task<ProfileResponse> GetAsync(CancellationToken cancellationToken) => ToResponse(await CurrentUserAsync(cancellationToken));

    public async Task<ProfileResponse> UpdateAsync(UpdateProfileRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FirstName) || string.IsNullOrWhiteSpace(request.LastName) || string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@')) throw new BusinessException("Unesite ime, prezime i validan email.");
        var user = await CurrentUserAsync(cancellationToken);
        if (!string.IsNullOrEmpty(request.ProfileImageUrl) && request.ProfileImageUrl != user.ProfileImageUrl && !request.ProfileImageUrl.StartsWith("/api/profile/images/" + user.Id.ToString("N") + "-"))
            throw new BusinessException("Profilna slika mora biti vaša prethodno učitana slika.");
        var email = InputValidation.Email(request.Email);
        InputValidation.Text(request.FirstName, "Ime", 100);
        InputValidation.Text(request.LastName, "Prezime", 100);
        if (request.CityId.HasValue && !await db.Cities.AnyAsync(x => x.Id == request.CityId && x.IsActive, cancellationToken)) throw new BusinessException("Odaberite aktivan grad iz liste.");
        if (await db.Users.AnyAsync(other => other.Id != user.Id && other.Email == email, cancellationToken)) throw new BusinessException("Korisnik s tim emailom već postoji.");
        if (!string.IsNullOrWhiteSpace(request.NewPassword))
        {
            if (string.IsNullOrWhiteSpace(request.CurrentPassword) || !BCrypt.Net.BCrypt.Verify(request.CurrentPassword, user.PasswordHash)) throw new BusinessException("Trenutna lozinka nije ispravna.");
            InputValidation.Password(request.NewPassword);
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
            user.TokenVersion++;
        }
        user.FirstName = request.FirstName.Trim(); user.LastName = request.LastName.Trim(); user.Email = email; user.ProfileImageUrl = string.IsNullOrWhiteSpace(request.ProfileImageUrl) ? null : request.ProfileImageUrl.Trim(); user.NotificationsEnabled = request.NotificationsEnabled;
        user.CityId = request.CityId;
        await db.SaveChangesAsync(cancellationToken);
        return await GetAsync(cancellationToken);
    }

    private async Task<AppUser> CurrentUserAsync(CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) throw new UnauthorizedException("Prijava je obavezna.");
        return await db.Users.Include(x => x.City).SingleOrDefaultAsync(user => user.Id == id, cancellationToken) ?? throw new UnauthorizedException("Korisnik nije pronađen.");
    }
    private static ProfileResponse ToResponse(AppUser user) => new(user.FirstName, user.LastName, user.Username, user.Email, user.ProfileImageUrl, user.NotificationsEnabled, user.CityId, user.City?.Name);
}
