using System.Security.Claims;
using BeautyStudio.Api.Contracts.Activities;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;
public sealed class ActivityService(BeautyStudioDbContext db, IHttpContextAccessor accessor)
{
    public async Task RecordAsync(RecordActivityRequest request, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)) throw new UnauthorizedException("Prijava je obavezna.");
        if (!Enum.IsDefined(request.Type) || request.Type == UserActivityType.ServiceReserved) throw new BusinessException("Rezervacije se evidentiraju isključivo kroz kreiranje stvarnog termina.");
        if ((request.Type is UserActivityType.ServiceViewed or UserActivityType.ServiceReserved) && request.ServiceId is null || request.Type == UserActivityType.CategoryViewed && request.CategoryId is null || request.Type == UserActivityType.BlogViewed && request.BlogPostId is null || request.Type == UserActivityType.GalleryViewed && request.GalleryItemId is null)
            throw new BusinessException("Za odabranu vrstu aktivnosti nedostaje povezani sadržaj.");
        if (request.ServiceId is int serviceId && !await db.Services.AnyAsync(item => item.Id == serviceId && item.IsActive, cancellationToken)) throw new NotFoundException("Usluga nije pronađena.");
        if (request.CategoryId is int categoryId && !await db.ServiceCategories.AnyAsync(item => item.Id == categoryId && item.IsActive, cancellationToken)) throw new NotFoundException("Kategorija nije pronađena.");
        if (request.BlogPostId is Guid blogPostId && !await db.BlogPosts.AnyAsync(item => item.Id == blogPostId && item.IsPublished, cancellationToken)) throw new NotFoundException("Objava nije pronađena.");
        if (request.GalleryItemId is Guid galleryItemId && !await db.GalleryItems.AnyAsync(item => item.Id == galleryItemId && item.IsActive, cancellationToken)) throw new NotFoundException("Galerija nije pronađena.");
        var category = request.ServiceId is int service ? await db.Services.Where(x => x.Id == service).Select(x => (int?)x.CategoryId).SingleAsync(cancellationToken)
            : request.BlogPostId is Guid blog ? await db.BlogPosts.Where(x => x.Id == blog).Select(x => (int?)x.CategoryId).SingleAsync(cancellationToken)
            : request.GalleryItemId is Guid gallery ? await db.GalleryItems.Where(x => x.Id == gallery).Select(x => (int?)x.CategoryId).SingleAsync(cancellationToken)
            : request.CategoryId;
        db.UserActivities.Add(new UserActivity { Id = Guid.NewGuid(), UserId = userId, Type = request.Type, ServiceId = request.Type == UserActivityType.ServiceViewed ? request.ServiceId : null, CategoryId = category, BlogPostId = request.Type == UserActivityType.BlogViewed ? request.BlogPostId : null, GalleryItemId = request.Type == UserActivityType.GalleryViewed ? request.GalleryItemId : null });
        await db.SaveChangesAsync(cancellationToken);
    }
}
