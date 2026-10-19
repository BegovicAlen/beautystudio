using BeautyStudio.Api.Contracts.Administration;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BeautyStudio.Api.Services;

public sealed class AdministrationService(BeautyStudioDbContext db, IHttpContextAccessor accessor)
{
    public async Task<ManagedServiceResponse> CreateServiceAsync(UpsertServiceRequest request, CancellationToken cancellationToken)
    {
        Validate(request);
        var category = await ActiveCategoryAsync(request.CategoryId, cancellationToken);
        var service = new BeautyService { Name = request.Name.Trim(), Description = request.Description.Trim(), Price = request.Price, DurationMinutes = request.DurationMinutes, CategoryId = category.Id, IsActive = request.IsActive };
        db.Services.Add(service);
        await db.SaveChangesAsync(cancellationToken);
        return new ManagedServiceResponse(service.Id, service.Name, service.Description, service.Price, service.DurationMinutes, category.Id, category.Name, service.IsActive);
    }

    public async Task<ManagedServiceResponse> UpdateServiceAsync(int id, UpsertServiceRequest request, CancellationToken cancellationToken)
    {
        Validate(request);
        var service = await db.Services.SingleOrDefaultAsync(service => service.Id == id, cancellationToken) ?? throw new NotFoundException("Usluga nije pronađena.");
        var category = await ActiveCategoryAsync(request.CategoryId, cancellationToken);
        service.Name = request.Name.Trim(); service.Description = request.Description.Trim(); service.Price = request.Price; service.DurationMinutes = request.DurationMinutes; service.CategoryId = category.Id; service.IsActive = request.IsActive;
        await db.SaveChangesAsync(cancellationToken);
        return new ManagedServiceResponse(service.Id, service.Name, service.Description, service.Price, service.DurationMinutes, category.Id, category.Name, service.IsActive);
    }

    public async Task<ManagedCategoryResponse> CreateCategoryAsync(UpsertCategoryRequest request, CancellationToken cancellationToken)
    {
        var name = ValidateCategory(request.Name);
        if (await db.ServiceCategories.AnyAsync(category => category.Name == name, cancellationToken)) throw new BusinessException("Kategorija s ovim nazivom već postoji.");
        var category = new ServiceCategory { Name = name, IsActive = request.IsActive };
        db.ServiceCategories.Add(category);
        await db.SaveChangesAsync(cancellationToken);
        return new ManagedCategoryResponse(category.Id, category.Name, category.IsActive, 0);
    }

    public async Task<ManagedCategoryResponse> UpdateCategoryAsync(int id, UpsertCategoryRequest request, CancellationToken cancellationToken)
    {
        var name = ValidateCategory(request.Name);
        var category = await db.ServiceCategories.Include(category => category.Services).SingleOrDefaultAsync(category => category.Id == id, cancellationToken) ?? throw new NotFoundException("Kategorija nije pronađena.");
        if (await db.ServiceCategories.AnyAsync(other => other.Id != id && other.Name == name, cancellationToken)) throw new BusinessException("Kategorija s ovim nazivom već postoji.");
        if (!request.IsActive && category.Services.Any(service => service.IsActive)) throw new BusinessException("Prije deaktivacije kategorije deaktivirajte njene aktivne usluge.");
        category.Name = name; category.IsActive = request.IsActive;
        await db.SaveChangesAsync(cancellationToken);
        return new ManagedCategoryResponse(category.Id, category.Name, category.IsActive, category.Services.Count);
    }

    public async Task<ManagedUserResponse> CreateUserAsync(CreateUserRequest request, CancellationToken cancellationToken)
    {
        var (firstName, lastName, username, email, role) = await ValidateUserAsync(request.FirstName, request.LastName, request.Username, request.Email, request.Role, null, cancellationToken);
        InputValidation.Password(request.Password);
        var user = new AppUser { Id = Guid.NewGuid(), FirstName = firstName, LastName = lastName, Username = username, Email = email, PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password), Role = role, IsActive = request.IsActive };
        db.Users.Add(user);
        await db.SaveChangesAsync(cancellationToken);
        return ToResponse(user);
    }

    public async Task<ManagedUserResponse> UpdateUserAsync(Guid id, UpdateUserRequest request, CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleOrDefaultAsync(user => user.Id == id, cancellationToken) ?? throw new NotFoundException("Korisnik nije pronađen.");
        var (firstName, lastName, username, email, role) = await ValidateUserAsync(request.FirstName, request.LastName, request.Username, request.Email, request.Role, id, cancellationToken);
        if (CurrentUserId() == id && (!request.IsActive || role != UserRole.Admin)) throw new BusinessException("Ne možete deaktivirati vlastiti administratorski račun niti mu promijeniti ulogu.");
        if (user.Role != role || user.IsActive != request.IsActive || !string.IsNullOrWhiteSpace(request.Password)) user.TokenVersion++;
        user.FirstName = firstName; user.LastName = lastName; user.Username = username; user.Email = email; user.Role = role; user.IsActive = request.IsActive;
        if (!string.IsNullOrWhiteSpace(request.Password))
        {
            InputValidation.Password(request.Password);
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
        }
        await db.SaveChangesAsync(cancellationToken);
        return ToResponse(user);
    }

    private async Task<ServiceCategory> ActiveCategoryAsync(int id, CancellationToken cancellationToken) => await db.ServiceCategories.SingleOrDefaultAsync(category => category.Id == id && category.IsActive, cancellationToken) ?? throw new BusinessException("Odabrana aktivna kategorija nije pronađena.");
    private static void Validate(UpsertServiceRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name) || string.IsNullOrWhiteSpace(request.Description)) throw new BusinessException("Naziv i opis usluge su obavezni.");
        InputValidation.Text(request.Name, "Naziv", 150);
        InputValidation.Text(request.Description, "Opis", 2000);
        if (request.Price < .01m || request.Price > 10000 || decimal.Round(request.Price, 2) != request.Price || request.DurationMinutes is < 5 or > 660) throw new BusinessException("Cijena mora biti između 0,01 i 10000 KM, s najviše dvije decimale, a trajanje između 5 i 660 minuta.");
    }
    private static string ValidateCategory(string value)
    {
        return InputValidation.Text(value, "Naziv kategorije", 150);
    }

    private async Task<(string FirstName, string LastName, string Username, string Email, UserRole Role)> ValidateUserAsync(string firstName, string lastName, string username, string email, string role, Guid? currentId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(firstName) || string.IsNullOrWhiteSpace(lastName) || string.IsNullOrWhiteSpace(username) || username.Trim().Length is < 3 or > 50 || string.IsNullOrWhiteSpace(email) || !email.Contains('@')) throw new BusinessException("Unesite ime, prezime, korisničko ime (3-50 znakova) i validan email.");
        if (!Enum.TryParse<UserRole>(role, true, out var parsedRole) || !Enum.IsDefined(parsedRole)) throw new BusinessException("Uloga korisnika nije validna.");
        var normalizedUsername = username.Trim().ToLowerInvariant();
        InputValidation.Text(firstName, "Ime", 100);
        InputValidation.Text(lastName, "Prezime", 100);
        var normalizedEmail = InputValidation.Email(email);
        if (await db.Users.AnyAsync(user => user.Id != currentId && user.Username == normalizedUsername, cancellationToken)) throw new BusinessException("Korisničko ime je zauzeto.");
        if (await db.Users.AnyAsync(user => user.Id != currentId && user.Email == normalizedEmail, cancellationToken)) throw new BusinessException("Korisnik s tim emailom već postoji.");
        return (firstName.Trim(), lastName.Trim(), normalizedUsername, normalizedEmail, parsedRole);
    }

    private Guid? CurrentUserId() => Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
    private static ManagedUserResponse ToResponse(AppUser user) => new(user.Id, user.FirstName, user.LastName, user.Username, user.Email, user.Role.ToString(), user.IsActive);
}
