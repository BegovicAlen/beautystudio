using BeautyStudio.Api.Contracts.Information;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace BeautyStudio.Api.Services;
public sealed class InformationService(BeautyStudioDbContext db, IMemoryCache cache)
{
    public async Task<FaqResponse> SaveFaqAsync(Guid? id, UpsertFaqRequest request, CancellationToken ct)
    {
        var question = InputValidation.Text(request.Question, "Pitanje", 300);
        var answer = InputValidation.Text(request.Answer, "Odgovor", 3000);
        if (request.SortOrder is < 0 or > 10000) throw new BusinessException("Redoslijed mora biti između 0 i 10000.");
        var item = id == null ? new FaqEntry { Id = Guid.NewGuid(), Question = question, Answer = answer } : await db.FaqEntries.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw new NotFoundException("FAQ nije pronađen.");
        item.Question = question; item.Answer = answer; item.IsActive = request.IsActive; item.SortOrder = request.SortOrder;
        item.StudioAboutId = await db.StudioAbouts.Select(x => x.Id).SingleAsync(ct);
        if (id == null) db.FaqEntries.Add(item);
        await db.SaveChangesAsync(ct);
        return new FaqResponse(item.Id, item.Question, item.Answer, item.IsActive, item.SortOrder);
    }
    public async Task<AboutResponse> AboutAsync(CancellationToken ct) => (await cache.GetOrCreateAsync("studio.about", async entry => {
        entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(30);
        var x = await db.StudioAbouts.AsNoTracking().Include(x => x.City).SingleAsync(ct);
        var clients = await db.Users.CountAsync(x => x.Role == UserRole.Client, ct);
        var average = await db.Reviews.AverageAsync(x => (double?)x.Rating, ct) ?? 0;
        return new AboutResponse(x.Title, x.Content, x.ImageUrl, x.Address, x.Phone, x.Email, x.FoundedYear, x.OpeningHour, x.ClosingHour, x.DepositPercent, x.CityId, x.City?.Name, clients, average);
    }))!;
    public async Task<AboutResponse> SaveAboutAsync(UpsertAboutRequest r, CancellationToken ct)
    {
        InputValidation.Text(r.Title, "Naslov", 200);
        InputValidation.Text(r.Content, "Opis", 5000);
        InputValidation.Text(r.Address, "Adresa", 200);
        var phone = InputValidation.Phone(r.Phone);
        var email = InputValidation.Email(r.Email);
        if (r.OpeningHour is < 0 or > 23 || r.ClosingHour <= r.OpeningHour || r.ClosingHour > 23 || r.DepositPercent is < 1 or > 100 || r.FoundedYear < 1900 || r.FoundedYear > DateTime.UtcNow.Year) throw new BusinessException("Provjerite radno vrijeme (0–23), godinu osnivanja i avans (1–100%).");
        if (r.CityId == null || !await db.Cities.AnyAsync(x => x.Id == r.CityId && x.IsActive, ct)) throw new BusinessException("Odaberite grad salona.");
        var x = await db.StudioAbouts.SingleAsync(ct);
        x.Title = r.Title.Trim(); x.Content = r.Content.Trim(); x.ImageUrl = string.IsNullOrWhiteSpace(r.ImageUrl) ? null : r.ImageUrl.Trim();
        x.Address = r.Address.Trim(); x.Phone = phone; x.Email = email; x.FoundedYear = r.FoundedYear; x.OpeningHour = r.OpeningHour; x.ClosingHour = r.ClosingHour; x.DepositPercent = r.DepositPercent; x.CityId = r.CityId;
        await db.SaveChangesAsync(ct);
        cache.Remove("studio.about");
        return await AboutAsync(ct);
    }
}
