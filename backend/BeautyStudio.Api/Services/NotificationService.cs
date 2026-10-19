using System.Security.Claims;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Contracts.Notifications;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;
public sealed class NotificationService(BeautyStudioDbContext db, IHttpContextAccessor accessor)
{
    public async Task SendAsync(SendNoticeRequest request, CancellationToken ct)
    {
        var title = InputValidation.Text(request.Title, "Naslov", 200);
        var message = InputValidation.Text(request.Message, "Tekst obavijesti", 2000);
        if (!await db.Users.AnyAsync(x => x.Id == request.RecipientId && x.IsActive, ct)) throw new BusinessException("Odaberite aktivnog korisnika.");
        if (!await db.Users.AnyAsync(x => x.Id == request.RecipientId && x.NotificationsEnabled, ct)) throw new BusinessException("Odabrani korisnik je isključio primanje obavijesti.");
        if (!await db.NotificationTypes.AnyAsync(x => x.Id == request.NotificationTypeId && x.IsActive, ct)) throw new BusinessException("Odaberite aktivan tip obavijesti.");
        db.NotificationOutbox.Add(new BeautyStudio.Api.Domain.NotificationOutbox { Id = Guid.NewGuid(), UserId = request.RecipientId, NotificationTypeId = request.NotificationTypeId, Title = title, Message = message });
        await db.SaveChangesAsync(ct);
    }
    private Guid UserId() => Guid.Parse(accessor.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    public async Task MarkAllReadAsync(CancellationToken token)
    {
        var userId = UserId();
        await db.Notifications.Where(n => n.UserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(updates => updates.SetProperty(n => n.IsRead, true), token);
    }
    public async Task MarkReadAsync(Guid id, CancellationToken token) { var item = await db.Notifications.SingleOrDefaultAsync(n => n.Id == id && n.UserId == UserId(), token) ?? throw new NotFoundException("Notifikacija nije pronađena."); item.IsRead = true; await db.SaveChangesAsync(token); }
}
