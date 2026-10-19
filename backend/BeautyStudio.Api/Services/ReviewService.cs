using System.Security.Claims;
using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Contracts.Reviews;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class ReviewService(BeautyStudioDbContext db, IHttpContextAccessor accessor, NotificationComposer notifications)
{
    public async Task<ReviewResponse> CreateAsync(CreateReviewRequest request, CancellationToken cancellationToken)
    {
        if (request.Rating is < 1 or > 5) throw new BusinessException("Ocjena mora biti između 1 i 5.");
        if (request.Comment?.Length > 2000) throw new BusinessException("Komentar može sadržavati najviše 2000 znakova.");
        var userId = CurrentUserId();
        var reservation = await db.Reservations.Include(item => item.Service).Include(item => item.User).SingleOrDefaultAsync(item => item.Id == request.ReservationId && item.UserId == userId, cancellationToken) ?? throw new NotFoundException("Rezervacija nije pronađena.");
        if (reservation.Status != ReservationStatus.Completed) throw new BusinessException("Recenziju je moguće ostaviti samo nakon završenog termina.");
        if (await db.Reviews.AnyAsync(item => item.ReservationId == reservation.Id, cancellationToken)) throw new BusinessException("Recenzija za ovaj termin već postoji.");

        var review = new Review { Id = Guid.NewGuid(), ReservationId = reservation.Id, UserId = userId, ServiceId = reservation.ServiceId, Rating = request.Rating, Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim() };
        db.Reviews.Add(review);
        var clientName = $"{reservation.User.FirstName} {reservation.User.LastName}";
        await notifications.StaffAsync(
            "ReviewCreated",
            "Nova recenzija",
            $"{clientName} je ocijenio/la uslugu {reservation.Service.Name} ocjenom {review.Rating}/5. Otvorite Ocjene usluga na početnoj stranici za komentar.",
            cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        return new ReviewResponse(review.Id, review.ServiceId, clientName, review.Rating, review.Comment, review.CreatedAtUtc);
    }

    public async Task<PagedResponse<ReviewResponse>> GetForServiceAsync(int serviceId, int page, int pageSize, CancellationToken cancellationToken)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var query = db.Reviews.AsNoTracking().Where(item => item.ServiceId == serviceId);
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderByDescending(item => item.CreatedAtUtc).Skip((page - 1) * pageSize).Take(pageSize)
            .Select(item => new ReviewResponse(item.Id, item.ServiceId, $"{item.User.FirstName} {item.User.LastName}", item.Rating, item.Comment, item.CreatedAtUtc)).ToListAsync(cancellationToken);
        return new PagedResponse<ReviewResponse>(total, page, pageSize, items);
    }

    private Guid CurrentUserId() => Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId) ? userId : throw new UnauthorizedException("Prijava je obavezna.");
}
