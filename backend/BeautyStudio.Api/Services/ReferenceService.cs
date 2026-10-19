using BeautyStudio.Api.Contracts.Administration;
using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class ReferenceService(BeautyStudioDbContext db)
{
    public async Task<PagedResponse<ReferenceResponse>> GetAsync(string kind, ListQuery q, CancellationToken ct)
    {
        IQueryable<ReferenceResponse> source = kind switch {
            "cities" => Named(db.Cities.AsNoTracking(), q).Select(x => new ReferenceResponse(x.Id, x.Name, x.IsActive, null)),
            "statuses" => Named(db.ReservationStatuses.AsNoTracking(), q).Select(x => new ReferenceResponse(x.Id, x.Name, x.IsActive, x.Code.ToString())),
            "notification-types" => Named(db.NotificationTypes.AsNoTracking(), q).Select(x => new ReferenceResponse(x.Id, x.Name, x.IsActive, x.Code)),
            "categories" => Named(db.ServiceCategories.AsNoTracking(), q).Select(x => new ReferenceResponse(x.Id, x.Name, x.IsActive, null)),
            _ => throw new NotFoundException("Vrsta referentnih podataka nije pronađena.")
        };
        return await source.PageAsync(q, ct);
    }
    private static IQueryable<T> Named<T>(IQueryable<T> source, ListQuery q) where T : class
    {
        if (q.Active.HasValue) source = source.Where(x => EF.Property<bool>(x, "IsActive") == q.Active.Value);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => EF.Property<string>(x, "Name").Contains(q.Search));
        return source.OrderBy(x => EF.Property<string>(x, "Name")).ThenBy(x => EF.Property<int>(x, "Id"));
    }

    public async Task<ReferenceResponse> SaveAsync(string kind, int? id, UpsertReferenceRequest request, CancellationToken ct)
    {
        var name = InputValidation.Text(request.Name, "Naziv", 100);
        await using var transaction = await BookingLock.BeginAsync(db, ct);
        switch (kind)
        {
            case "cities":
                if (await db.Cities.AnyAsync(x => x.Name == name && x.Id != id, ct)) throw new BusinessException("Grad s tim nazivom već postoji.");
                var city = id == null ? new City { Name = name } : await db.Cities.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw new NotFoundException("Grad nije pronađen.");
                if (!request.IsActive && (await db.Users.AnyAsync(x => x.CityId == city.Id, ct) || await db.StudioAbouts.AnyAsync(x => x.CityId == city.Id, ct))) throw new BusinessException("Grad se koristi u profilu ili adresi salona i ne može se deaktivirati.");
                city.Name = name; city.IsActive = request.IsActive;
                if (id == null) db.Cities.Add(city);
                await db.SaveChangesAsync(ct);
                await transaction.CommitAsync(ct);
                return new ReferenceResponse(city.Id, city.Name, city.IsActive);
            case "statuses":
                if (!Enum.TryParse<ReservationStatus>(request.Code, out var code) || !Enum.IsDefined(code)) throw new BusinessException("Odaberite poslovno stanje: Pending, Confirmed, Cancelled ili Completed.");
                var status = id == null ? new ReservationStatusDefinition { Code = code, Name = name } : await db.ReservationStatuses.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw new NotFoundException("Status nije pronađen.");
                if (id != null && status.Code != code) throw new BusinessException("Poslovno stanje već korištenog statusa nije moguće promijeniti. Dodajte novi naziv statusa.");
                if (await db.ReservationStatuses.AnyAsync(x => x.Name == name && x.Id != id, ct)) throw new BusinessException("Status s tim nazivom već postoji.");
                if (!request.IsActive && (await db.Reservations.AnyAsync(x => x.StatusDefinitionId == status.Id, ct) || !await db.ReservationStatuses.AnyAsync(x => x.Id != status.Id && x.Code == code && x.IsActive, ct))) throw new BusinessException("Status se koristi u rezervacijama ili je jedini aktivan za ovo poslovno stanje.");
                status.Name = name; status.IsActive = request.IsActive;
                if (id == null) db.ReservationStatuses.Add(status);
                await db.SaveChangesAsync(ct);
                await transaction.CommitAsync(ct);
                return new ReferenceResponse(status.Id, status.Name, status.IsActive, status.Code.ToString());
            case "notification-types":
                var type = id == null ? new NotificationType { Code = request.Code ?? "custom_" + Guid.NewGuid().ToString("N"), Name = name } : await db.NotificationTypes.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw new NotFoundException("Tip nije pronađen.");
                var requestedCode = request.Code ?? type.Code;
                if (!System.Text.RegularExpressions.Regex.IsMatch(requestedCode, "^[A-Za-z][A-Za-z0-9_]{2,59}$")) throw new BusinessException("Kod tipa mora imati 3–60 slova, cifara ili donjih crtica.");
                if (id != null && type.Code != requestedCode) throw new BusinessException("Kod tipa notifikacije nije moguće promijeniti.");
                if (await db.NotificationTypes.AnyAsync(x => x.Code == requestedCode && x.Id != id, ct)) throw new BusinessException("Tip već postoji.");
                if (!request.IsActive && await db.NotificationOutbox.AnyAsync(x => x.NotificationTypeId == type.Id && x.PublishedAtUtc == null, ct)) throw new BusinessException("Tip se koristi u neobrađenim obavijestima.");
                type.Code = requestedCode; type.Name = name; type.IsActive = request.IsActive;
                if (id == null) db.NotificationTypes.Add(type);
                await db.SaveChangesAsync(ct);
                await transaction.CommitAsync(ct);
                return new ReferenceResponse(type.Id, type.Name, type.IsActive, type.Code);
            default: throw new NotFoundException("Vrsta referentnih podataka nije pronađena.");
        }
    }
}
