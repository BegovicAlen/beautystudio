using System.Security.Claims;
using BeautyStudio.Api.Contracts.Recommendations;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class RecommendationService(BeautyStudioDbContext db, IHttpContextAccessor http)
{
    private Guid UserId() => Guid.TryParse(http.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : throw new UnauthorizedException("Prijava je obavezna.");
    private async Task<Dictionary<int, double>> InterestsAsync(CancellationToken ct)
    {
        var id = UserId();
        var since = DateTime.UtcNow.AddDays(-90);
        return await db.UserActivities.AsNoTracking().Where(x => x.UserId == id && x.CategoryId != null && x.CreatedAtUtc >= since)
            .GroupBy(x => x.CategoryId!.Value).Select(g => new { Id = g.Key, Score = g.Sum(x => x.Type == UserActivityType.ServiceReserved ? 5.0 : x.Type == UserActivityType.CategoryViewed ? 2.0 : 1.0) }).ToDictionaryAsync(x => x.Id, x => x.Score, ct);
    }
    private static double Normalized(int count, int maximum) => maximum == 0 ? 0 : (double)count / maximum;

    public async Task<IReadOnlyList<RecommendationResponse>> GetForCurrentUserAsync(CancellationToken ct)
    {
        var interests = await InterestsAsync(ct);
        var since = DateTime.UtcNow.AddDays(-30);
        var services = await db.Services.AsNoTracking().Where(x => x.IsActive && x.Category.IsActive).Select(x => new { x.Id, x.Name, x.Price, x.CategoryId, Category = x.Category.Name }).ToListAsync(ct);
        var bookings = await db.Reservations.AsNoTracking().Where(x => x.CreatedAtUtc >= since && x.Status != ReservationStatus.Cancelled).GroupBy(x => x.ServiceId).Select(g => new { Id = g.Key, Count = g.Count() }).ToDictionaryAsync(x => x.Id, x => x.Count, ct);
        var views = await db.UserActivities.AsNoTracking().Where(x => x.CreatedAtUtc >= since && x.Type == UserActivityType.ServiceViewed && x.ServiceId != null).GroupBy(x => x.ServiceId!.Value).Select(g => new { Id = g.Key, Count = g.Count() }).ToDictionaryAsync(x => x.Id, x => x.Count, ct);
        var ratings = await db.Reviews.AsNoTracking().GroupBy(x => x.ServiceId).Select(g => new { Id = g.Key, Average = g.Average(x => (double)x.Rating), Count = g.Count() }).ToDictionaryAsync(x => x.Id, ct);
        var maximumInterest = interests.Values.DefaultIfEmpty(0).Max();
        var maximumBookings = bookings.Values.DefaultIfEmpty(0).Max();
        var maximumViews = views.Values.DefaultIfEmpty(0).Max();
        return services.Select(service => {
            var interest = maximumInterest == 0 ? 0 : interests.GetValueOrDefault(service.CategoryId) / maximumInterest;
            var popular = .8 * Normalized(bookings.GetValueOrDefault(service.Id), maximumBookings) + .2 * Normalized(views.GetValueOrDefault(service.Id), maximumViews);
            var rating = ratings.TryGetValue(service.Id, out var r) ? r.Average / 5 * Math.Min(1, r.Count / 3.0) : 0;
            var score = maximumInterest > 0 ? .6 * interest + .25 * popular + .15 * rating : .7 * popular + .3 * rating;
            var reason = interest > 0 ? $"Preporučeno zbog vašeg interesa za kategoriju {service.Category}." : bookings.GetValueOrDefault(service.Id) > 0 ? "Popularno među korisnicima u posljednjih 30 dana." : rating > 0 ? "Preporučeno na osnovu ocjena korisnika." : "Istražite ovu uslugu iz ponude salona.";
            return new { service, Score = score, Reason = reason };
        }).OrderByDescending(x => x.Score).ThenBy(x => x.service.Name).Take(5).Select(x => new RecommendationResponse(x.service.Id, x.service.Name, x.service.Price, x.Reason)).ToList();
    }

    public async Task<ContentRecommendationsResponse> GetContentForCurrentUserAsync(CancellationToken ct)
    {
        var interests = await InterestsAsync(ct);
        var max = interests.Values.DefaultIfEmpty(0).Max();
        var since = DateTime.UtcNow.AddDays(-30);
        var counts = await db.Reservations.AsNoTracking().Where(x => x.CreatedAtUtc >= since && x.Status != ReservationStatus.Cancelled).GroupBy(x => x.Service.CategoryId).Select(g => new { Id = g.Key, Count = g.Count() }).ToDictionaryAsync(x => x.Id, x => x.Count, ct);
        var maxCount = counts.Values.DefaultIfEmpty(0).Max();
        var categories = await db.ServiceCategories.AsNoTracking().Where(x => x.IsActive).ToListAsync(ct);
        var rankedCategories = categories.Select(x => new { Item = x, Score = (max > 0 ? .7 * interests.GetValueOrDefault(x.Id) / max : 0) + .3 * Normalized(counts.GetValueOrDefault(x.Id), maxCount) }).OrderByDescending(x => x.Score).ThenBy(x => x.Item.Name).Take(3)
            .Select(x => new CategoryRecommendationResponse(x.Item.Id, x.Item.Name, interests.GetValueOrDefault(x.Item.Id) > 0 ? "Na osnovu vaših pregleda, čitanja sadržaja i rezervacija." : "Popularno na osnovu rezervacija posljednjih 30 dana.")).ToList();
        var id = UserId();
        var seen = await db.UserActivities.AsNoTracking().Where(x => x.UserId == id && x.BlogPostId != null).Select(x => x.BlogPostId!.Value).Distinct().ToListAsync(ct);
        var blogs = await db.BlogPosts.AsNoTracking().Where(x => x.IsPublished && x.Category.IsActive && !seen.Contains(x.Id)).Select(x => new { x.Id, x.Title, x.ImageUrl, x.CategoryId, x.PublishedAtUtc, Category = x.Category.Name }).ToListAsync(ct);
        var blogViews = await db.UserActivities.AsNoTracking().Where(x => x.CreatedAtUtc >= since && x.BlogPostId != null).GroupBy(x => x.BlogPostId!.Value).Select(g => new { Id = g.Key, Count = g.Count() }).ToDictionaryAsync(x => x.Id, x => x.Count, ct);
        var maxViews = blogViews.Values.DefaultIfEmpty(0).Max();
        var rankedBlogs = blogs.Select(x => new { Item = x, Score = (max > 0 ? .6 * interests.GetValueOrDefault(x.CategoryId) / max : 0) + .3 * Normalized(blogViews.GetValueOrDefault(x.Id), maxViews) + .1 / (1 + Math.Max(0, (DateTime.UtcNow - x.PublishedAtUtc).TotalDays)) })
            .OrderByDescending(x => x.Score).ThenBy(x => x.Item.Title).Take(3).Select(x => new BlogRecommendationResponse(x.Item.Id, x.Item.Title, x.Item.ImageUrl, interests.GetValueOrDefault(x.Item.CategoryId) > 0 ? $"Povezano s vašim interesom za kategoriju {x.Item.Category}." : "Popularan ili nov sadržaj iz ponude salona.")).ToList();
        return new ContentRecommendationsResponse(rankedCategories, rankedBlogs);
    }
}
