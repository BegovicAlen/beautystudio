using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class NotificationComposer(BeautyStudioDbContext db)
{
    private Dictionary<string,int>? types;
    private readonly Dictionary<Guid,bool> preferences = new();
    private List<Guid>? staff;
    private async Task<int?> TypeAsync(string code, CancellationToken ct)
    {
        types ??= await db.NotificationTypes.Where(x => x.IsActive).ToDictionaryAsync(x => x.Code, x => x.Id, ct);
        return types.TryGetValue(code, out var id) ? id : null;
    }
    public async Task PrimeAsync(IEnumerable<Guid> ids, CancellationToken ct)
    {
        var missing = ids.Distinct().Where(id => !preferences.ContainsKey(id)).ToList();
        if (missing.Count == 0) return;
        var rows = await db.Users.Where(x => missing.Contains(x.Id)).Select(x => new { x.Id, x.NotificationsEnabled }).ToListAsync(ct);
        foreach (var x in rows) preferences[x.Id] = x.NotificationsEnabled;
    }
    public async Task AddAsync(Guid userId, string code, string title, string message, CancellationToken ct)
    {
        await PrimeAsync([userId], ct);
        if (!preferences.GetValueOrDefault(userId)) return;
        var type = await TypeAsync(code, ct);
        if (type is null) return;
        db.NotificationOutbox.Add(new NotificationOutbox { Id = Guid.NewGuid(), UserId = userId, NotificationTypeId = type.Value, Title = title, Message = message });
    }

    public async Task StaffAsync(string code, string title, string message, CancellationToken ct)
    {
        var type = await TypeAsync(code, ct);
        if (type is null) return;
        var recipients = staff ??= await db.Users.Where(x => x.IsActive && x.NotificationsEnabled && (x.Role == UserRole.Admin || x.Role == UserRole.Owner)).Select(x => x.Id).ToListAsync(ct);
        db.NotificationOutbox.AddRange(recipients.Select(id => new NotificationOutbox { Id = Guid.NewGuid(), UserId = id, NotificationTypeId = type.Value, Title = title, Message = message }));
    }
}
