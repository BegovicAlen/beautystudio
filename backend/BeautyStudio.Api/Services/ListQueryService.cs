using System.Security.Claims;
using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Contracts.Administration;
using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Contracts.Contact;
using BeautyStudio.Api.Contracts.Content;
using BeautyStudio.Api.Contracts.Information;
using BeautyStudio.Api.Contracts.Notifications;
using BeautyStudio.Api.Contracts.Payments;
using BeautyStudio.Api.Contracts.Reservations;
using BeautyStudio.Api.Contracts.Reviews;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class ListQueryService(BeautyStudioDbContext db, IHttpContextAccessor http, ReservationService reservations, AppConfiguration config)
{
    private Guid UserId() => Guid.Parse(http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    public Task<PagedResponse<ManagedUserResponse>> UsersAsync(ListQuery q, CancellationToken ct)
    {
        var source = db.Users.AsNoTracking().AsQueryable();
        if (q.Active.HasValue) source = source.Where(x => x.IsActive == q.Active);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.FirstName.Contains(q.Search) || x.LastName.Contains(q.Search) || x.Username.Contains(q.Search) || x.Email.Contains(q.Search));
        return source.OrderBy(x => x.FirstName).ThenBy(x => x.Id).Select(x => new ManagedUserResponse(x.Id, x.FirstName, x.LastName, x.Username, x.Email, x.Role.ToString(), x.IsActive)).PageAsync(q, ct);
    }
    public Task<PagedResponse<ManagedServiceResponse>> ServicesAsync(ListQuery q, bool managed, CancellationToken ct)
    {
        var source = db.Services.AsNoTracking().AsQueryable();
        if (!managed) source = source.Where(x => x.IsActive && x.Category.IsActive);
        if (q.Active.HasValue) source = source.Where(x => x.IsActive == q.Active);
        if (q.CategoryId.HasValue) source = source.Where(x => x.CategoryId == q.CategoryId);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Name.Contains(q.Search));
        return source.OrderBy(x => x.Name).ThenBy(x => x.Id).Select(x => new ManagedServiceResponse(x.Id, x.Name, x.Description, x.Price, x.DurationMinutes, x.CategoryId, x.Category.Name, x.IsActive)).PageAsync(q, ct);
    }
    public Task<PagedResponse<ManagedCategoryResponse>> CategoriesAsync(ListQuery q, CancellationToken ct)
    {
        var source = db.ServiceCategories.AsNoTracking().AsQueryable();
        if (q.Active.HasValue) source = source.Where(x => x.IsActive == q.Active);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Name.Contains(q.Search));
        return source.OrderBy(x => x.Name).Select(x => new ManagedCategoryResponse(x.Id, x.Name, x.IsActive, x.Services.Count)).PageAsync(q, ct);
    }
    public Task<PagedResponse<ManagedGalleryItemResponse>> GalleryAsync(ListQuery q, bool managed, CancellationToken ct)
    {
        var source = db.GalleryItems.AsNoTracking().AsQueryable();
        if (!managed) source = source.Where(x => x.IsActive && x.ServiceCategory.IsActive);
        if (q.Active.HasValue) source = source.Where(x => x.IsActive == q.Active);
        if (q.CategoryId.HasValue) source = source.Where(x => x.CategoryId == q.CategoryId);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Title.Contains(q.Search) || x.Description.Contains(q.Search) || x.ServiceCategory.Name.Contains(q.Search));
        return source.OrderByDescending(x => x.CreatedAtUtc).ThenBy(x => x.Id).Select(x => new ManagedGalleryItemResponse(x.Id, x.Title, x.ImageUrl, x.ServiceCategory.Name, x.IsActive, x.CreatedAtUtc, x.CategoryId, x.Description)).PageAsync(q, ct);
    }
    public Task<PagedResponse<ManagedBlogPostResponse>> BlogsAsync(ListQuery q, bool managed, CancellationToken ct)
    {
        var source = db.BlogPosts.AsNoTracking().AsQueryable();
        if (!managed) source = source.Where(x => x.IsPublished && x.Category.IsActive);
        if (q.Active.HasValue) source = source.Where(x => x.IsPublished == q.Active);
        if (q.CategoryId.HasValue) source = source.Where(x => x.CategoryId == q.CategoryId);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Title.Contains(q.Search));
        return source.OrderByDescending(x => x.PublishedAtUtc).ThenBy(x => x.Id).Select(x => new ManagedBlogPostResponse(x.Id, x.Title, x.Content.Length > 180 ? x.Content.Substring(0, 180) : x.Content, x.ImageUrl, x.IsPublished, x.PublishedAtUtc, x.CategoryId, x.Category.Name)).PageAsync(q, ct);
    }
    public async Task<ManagedBlogPostResponse> BlogAsync(Guid id, bool managed, CancellationToken ct) => await db.BlogPosts.AsNoTracking().Where(x => x.Id == id && (managed || x.IsPublished && x.Category.IsActive)).Select(x => new ManagedBlogPostResponse(x.Id, x.Title, x.Content, x.ImageUrl, x.IsPublished, x.PublishedAtUtc, x.CategoryId, x.Category.Name)).SingleOrDefaultAsync(ct) ?? throw new NotFoundException("Članak nije pronađen.");
    public Task<PagedResponse<FaqResponse>> FaqAsync(ListQuery q, bool managed, CancellationToken ct)
    {
        var source = db.FaqEntries.AsNoTracking().AsQueryable();
        if (!managed) source = source.Where(x => x.IsActive);
        if (q.Active.HasValue) source = source.Where(x => x.IsActive == q.Active);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Question.Contains(q.Search) || x.Answer.Contains(q.Search));
        return source.OrderBy(x => x.SortOrder).ThenBy(x => x.Id).Select(x => new FaqResponse(x.Id, x.Question, x.Answer, x.IsActive, x.SortOrder)).PageAsync(q, ct);
    }
    public Task<PagedResponse<ContactMessageResponse>> ContactsAsync(ListQuery q, CancellationToken ct)
    {
        var source = db.ContactMessages.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.FullName.Contains(q.Search) || x.Email.Contains(q.Search) || x.Message.Contains(q.Search));
        return source.OrderByDescending(x => x.CreatedAtUtc).ThenBy(x => x.Id).Select(x => new ContactMessageResponse(x.Id, x.FullName, x.Email, x.Phone, x.Message, x.CreatedAtUtc)).PageAsync(q, ct);
    }
    public Task<PagedResponse<NotificationResponse>> NotificationsAsync(ListQuery q, CancellationToken ct)
    {
        var id = UserId();
        var source = db.Notifications.AsNoTracking().Where(x => x.UserId == id);
        if (q.Active.HasValue) source = source.Where(x => x.IsRead != q.Active.Value);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Title.Contains(q.Search) || x.Message.Contains(q.Search));
        return source.OrderByDescending(x => x.CreatedAtUtc).ThenBy(x => x.Id).Select(x => new NotificationResponse(x.Id, x.Title, x.Message, x.IsRead, x.CreatedAtUtc)).PageAsync(q, ct);
    }
    public Task<PagedResponse<ServiceReviewSummaryResponse>> ReviewSummaryAsync(ListQuery q, CancellationToken ct)
    {
        var source = db.Reviews.AsNoTracking().GroupBy(x => new { x.ServiceId, x.Service.Name }).Select(g => new { g.Key.ServiceId, g.Key.Name, Count = g.Count(), Average = g.Average(x => (double)x.Rating) });
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Name.Contains(q.Search));
        return source.OrderByDescending(x => x.Average).ThenBy(x => x.ServiceId).Select(x => new ServiceReviewSummaryResponse(x.ServiceId, x.Name, x.Count, x.Average)).PageAsync(q, ct);
    }
    public Task<PagedResponse<PaymentResponse>> PaymentsAsync(ListQuery q, bool mine, CancellationToken ct)
    {
        var source = db.Payments.AsNoTracking().AsQueryable();
        if (mine) source = source.Where(x => x.Reservation.UserId == UserId());
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Reservation.Service.Name.Contains(q.Search) || x.Reservation.User.FirstName.Contains(q.Search) || x.Reservation.User.LastName.Contains(q.Search));
        if (!string.IsNullOrWhiteSpace(q.Status)) { if (!Enum.TryParse<PaymentStatus>(q.Status, true, out var status)) throw new BusinessException("Status plaćanja nije validan."); source = source.Where(x => x.Status == status); }
        if (q.From.HasValue) { var start = Utc(q.From.Value); source = source.Where(x => (x.PaidAtUtc ?? x.CreatedAtUtc) >= start); }
        if (q.To.HasValue) { var end = Utc(q.To.Value.AddDays(1)); source = source.Where(x => (x.PaidAtUtc ?? x.CreatedAtUtc) < end); }
        return source.OrderByDescending(x => x.CreatedAtUtc).ThenBy(x => x.Id).Select(PaymentProjection.Response).PageAsync(q, ct);
    }
    private DateTime Utc(DateOnly date) => TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(date.ToDateTime(TimeOnly.MinValue), DateTimeKind.Unspecified), TimeZoneInfo.FindSystemTimeZoneById(config.TimeZone));
    private IQueryable<Reservation> ReservationQuery(ListQuery q)
    {
        var source = db.Reservations.AsNoTracking().Include(x => x.Service).Include(x => x.User).AsQueryable();
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Service.Name.Contains(q.Search) || x.User.FirstName.Contains(q.Search) || x.User.LastName.Contains(q.Search) || x.User.Email.Contains(q.Search));
        if (!string.IsNullOrWhiteSpace(q.Status)) { if (!Enum.TryParse<ReservationStatus>(q.Status, true, out var status)) throw new BusinessException("Status rezervacije nije validan."); source = source.Where(x => x.Status == status); }
        if (q.From.HasValue) { var start = Utc(q.From.Value); source = source.Where(x => x.StartAtUtc >= start); }
        if (q.To.HasValue) { var end = Utc(q.To.Value.AddDays(1)); source = source.Where(x => x.StartAtUtc < end); }
        return source.OrderByDescending(x => x.CreatedAtUtc).ThenBy(x => x.Id);
    }
    public async Task<PagedResponse<ReservationResponse>> MineAsync(ListQuery q, CancellationToken ct)
    {
        var page = await ReservationQuery(q).Where(x => x.UserId == UserId()).PageAsync(q, ct);
        return new PagedResponse<ReservationResponse>(page.Total, page.Page, page.PageSize, await reservations.ClientResponsesAsync(page.Items, ct));
    }
    public async Task<PagedResponse<StaffReservationResponse>> ReservationsAsync(ListQuery q, CancellationToken ct)
    {
        var page = await ReservationQuery(q).PageAsync(q, ct);
        return new PagedResponse<StaffReservationResponse>(page.Total, page.Page, page.PageSize, await reservations.StaffResponsesAsync(page.Items, ct));
    }
    public Task<PagedResponse<ReservationHistoryResponse>> HistoryAsync(Guid id, ListQuery q, CancellationToken ct)
    {
        var source = db.ReservationStatusHistories.AsNoTracking().Where(x => x.ReservationId == id);
        if (!string.IsNullOrWhiteSpace(q.Search)) source = source.Where(x => x.Reason.Contains(q.Search));
        return source.OrderByDescending(x => x.ChangedAtUtc).Select(x => new ReservationHistoryResponse(x.Id, x.FromStatus, x.ToStatus, x.Reason, x.ChangedAtUtc, x.ChangedBy == null ? "Sistem" : x.ChangedBy.FirstName + " " + x.ChangedBy.LastName)).PageAsync(q, ct);
    }
}
