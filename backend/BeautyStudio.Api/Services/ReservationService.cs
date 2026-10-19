using System.Security.Claims;
using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Contracts.Reservations;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class ReservationService(BeautyStudioDbContext db, IHttpContextAccessor http, AppConfiguration config, NotificationComposer notifications, PaymentService payments) : IReservationService
{
    public async Task<AvailabilityResponse> GetAvailabilityAsync(int serviceId, DateOnly date, CancellationToken ct)
    {
        var service = await db.Services.AsNoTracking().SingleOrDefaultAsync(x => x.Id == serviceId && x.IsActive && x.Category.IsActive, ct) ?? throw new NotFoundException("Usluga nije dostupna.");
        var settings = await db.StudioAbouts.AsNoTracking().SingleAsync(ct);
        var zone = TimeZoneInfo.FindSystemTimeZoneById(config.TimeZone);
        var opening = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(date.ToDateTime(new TimeOnly(settings.OpeningHour, 0)), DateTimeKind.Unspecified), zone);
        var closing = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(date.ToDateTime(new TimeOnly(settings.ClosingHour, 0)), DateTimeKind.Unspecified), zone);
        var occupied = await db.Reservations.AsNoTracking().Where(x => x.Status != ReservationStatus.Cancelled && x.StartAtUtc < closing && x.EndAtUtc > opening).Select(x => new { x.StartAtUtc, x.EndAtUtc }).ToListAsync(ct);
        var hourly = Enumerable.Range(settings.OpeningHour, settings.ClosingHour - settings.OpeningHour).Select(h => TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(date.ToDateTime(new TimeOnly(h, 0)), DateTimeKind.Unspecified), zone));
        var candidates = hourly.Concat(occupied.Select(x => x.EndAtUtc)).Distinct().OrderBy(x => x);
        return new AvailabilityResponse(candidates.Where(start => start > DateTime.UtcNow && start >= opening && start.AddMinutes(service.DurationMinutes) <= closing && !occupied.Any(x => x.StartAtUtc < start.AddMinutes(service.DurationMinutes) && x.EndAtUtc > start)).ToList());
    }

    public async Task<ReservationResponse> CreateAsync(CreateReservationRequest request, CancellationToken ct)
    {
        if (request.StartAtUtc.Kind != DateTimeKind.Utc || request.StartAtUtc <= DateTime.UtcNow || request.StartAtUtc > DateTime.UtcNow.AddDays(90)) throw new BusinessException("Termin mora biti u budućnosti, unutar narednih 90 dana, izražen u UTC vremenu.");
        if (!Enum.IsDefined(request.PaymentMethod)) throw new BusinessException("Način plaćanja nije validan.");
        await using var tx = await BookingLock.BeginAsync(db, ct);
        var service = await db.Services.SingleOrDefaultAsync(x => x.Id == request.ServiceId && x.IsActive && x.Category.IsActive, ct) ?? throw new NotFoundException("Usluga nije dostupna.");
        var user = await db.Users.SingleAsync(x => x.Id == UserId(), ct);
        var end = request.StartAtUtc.AddMinutes(service.DurationMinutes);
        var settings = await db.StudioAbouts.AsNoTracking().SingleAsync(ct);
        var zone = TimeZoneInfo.FindSystemTimeZoneById(config.TimeZone);
        var localStart = TimeZoneInfo.ConvertTimeFromUtc(request.StartAtUtc, zone);
        var localEnd = TimeZoneInfo.ConvertTimeFromUtc(end, zone);
        if (localStart.Date != localEnd.Date || localStart.TimeOfDay < TimeSpan.FromHours(settings.OpeningHour) || localEnd.TimeOfDay > TimeSpan.FromHours(settings.ClosingHour)) throw new BusinessException($"Cijeli tretman mora stati u radno vrijeme salona ({settings.OpeningHour:00}:00–{settings.ClosingHour:00}:00).");
        if (await db.Reservations.AnyAsync(x => x.Status != ReservationStatus.Cancelled && x.StartAtUtc < end && x.EndAtUtc > request.StartAtUtc, ct)) throw new BusinessException("Odabrani termin više nije slobodan.");
        var r = new Reservation { Id = Guid.NewGuid(), UserId = user.Id, ServiceId = service.Id, StartAtUtc = request.StartAtUtc, EndAtUtc = end, PaymentMethod = request.PaymentMethod, TotalAmount = service.Price, DepositPercent = settings.DepositPercent, Currency = config.Currency };
        r.StatusDefinition = await StatusDefinitions.ResolveAsync(db, ReservationStatus.Pending, null, ct);
        r.StatusDefinitionId = r.StatusDefinition.Id;
        db.Reservations.Add(r);
        db.UserActivities.Add(new UserActivity { Id = Guid.NewGuid(), UserId = user.Id, Type = UserActivityType.ServiceReserved, ServiceId = service.Id, CategoryId = service.CategoryId });
        db.ReservationStatusHistories.Add(new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = r.Id, ChangedByUserId = user.Id, ToStatus = ReservationStatus.Pending, Reason = "Rezervacija kreirana." });
        var message = $"Termin za {service.Name}: {localStart:dd.MM.yyyy. HH:mm}. Rezervacija čeka potvrdu.";
        await notifications.AddAsync(user.Id, "ReservationCreated", "Rezervacija zaprimljena", message, ct);
        await notifications.StaffAsync("ReservationCreated", "Nova rezervacija", $"{user.FirstName} {user.LastName}: {message}", ct);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return (await ClientResponsesAsync([r], ct)).Single();
    }

    public async Task<ClientReservationHistoryResponse> GetClientHistoryAsync(Guid clientId, CancellationToken ct, BeautyStudio.Api.Contracts.Common.ListQuery? query = null)
    {
        RequireStaff();
        var client = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == clientId, ct) ?? throw new NotFoundException("Klijent nije pronađen.");
        query ??= new BeautyStudio.Api.Contracts.Common.ListQuery();
        var source = db.Reservations.Include(x => x.User).Include(x => x.Service).Where(x => x.UserId == clientId);
        if (!string.IsNullOrWhiteSpace(query.Search)) source = source.Where(x => x.Service.Name.Contains(query.Search));
        var page = await BeautyStudio.Api.Contracts.Common.Paging.PageAsync(source.OrderByDescending(x => x.StartAtUtc), query, ct);
        return new ClientReservationHistoryResponse(client.Id, $"{client.FirstName} {client.LastName}", client.Email, await StaffResponsesAsync(page.Items, ct), page.Total, page.Page, page.PageSize);
    }
    public Task<ReservationResponse> CancelMineAsync(Guid id, string reason, CancellationToken ct) => ChangeAsync(id, ReservationStatus.Cancelled, reason, true, ct);
    public Task<ReservationResponse> ChangeStatusAsync(Guid id, ChangeReservationStatusRequest request, CancellationToken ct) { RequireStaff(); return ChangeAsync(id, request.Status, request.Reason, false, ct, request.StatusDefinitionId); }

    private async Task<ReservationResponse> ChangeAsync(Guid id, ReservationStatus target, string reason, bool own, CancellationToken ct, int? definitionId = null)
    {
        reason = InputValidation.Text(reason, "Razlog promjene", 1000);
        await using var tx = await BookingLock.BeginAsync(db, ct);
        var r = await db.Reservations.Include(x => x.Service).Include(x => x.User).SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw new NotFoundException("Rezervacija nije pronađena.");
        if (own && r.UserId != UserId()) throw new NotFoundException("Rezervacija nije pronađena.");
        if (!ReservationStateMachine.CanTransition(r.Status, target)) throw new BusinessException("Ova promjena statusa nije dozvoljena.");
        var definition = await StatusDefinitions.ResolveAsync(db, target, definitionId, ct);
        if (target == ReservationStatus.Completed)
        {
            if (r.EndAtUtc > DateTime.UtcNow) throw new BusinessException("Tretman je moguće završiti tek nakon isteka zakazanog trajanja.");
            await payments.RecordOnSiteAsync(r, ct);
        }
        if (target == ReservationStatus.Cancelled) await payments.PrepareCancellationAsync(r, ct);
        var from = r.Status;
        r.Status = target;
        r.StatusDefinition = definition;
        r.StatusDefinitionId = definition.Id;
        if (target == ReservationStatus.Cancelled) r.CancellationReason = reason;
        db.ReservationStatusHistories.Add(new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = id, ChangedByUserId = UserId(), FromStatus = from, ToStatus = target, Reason = reason });
        if (own)
        {
            var local = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(r.StartAtUtc, DateTimeKind.Utc), TimeZoneInfo.FindSystemTimeZoneById(config.TimeZone));
            var message = $"{r.User.FirstName} {r.User.LastName} otkazao/la je termin za {r.Service.Name}, {local:dd.MM.yyyy. HH:mm}. Razlog: {reason}";
            await notifications.StaffAsync("ReservationStatusChanged", "Klijent otkazao rezervaciju", message, ct);
        }
        else
        {
            await StatusNotificationAsync(r, reason, ct);
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return (await ClientResponsesAsync([r], ct)).Single();
    }

    public async Task<int> ProcessExpiredReservationsAsync(CancellationToken ct)
    {
        await using var tx = await BookingLock.BeginAsync(db, ct);
        var expired = await db.Reservations.Include(x => x.Service).Where(x => x.Status == ReservationStatus.Pending && x.EndAtUtc <= DateTime.UtcNow).ToListAsync(ct);
        var ids = expired.Select(x => x.Id).ToList();
        var cancelledDefinition = await StatusDefinitions.ResolveAsync(db, ReservationStatus.Cancelled, null, ct);
        var existingPayments = await db.Payments.Include(x => x.Reservation).ThenInclude(x => x.Service).Where(x => ids.Contains(x.ReservationId)).ToDictionaryAsync(x => x.ReservationId, ct);
        await notifications.PrimeAsync(expired.Select(x => x.UserId), ct);
        foreach (var r in expired)
        {
            await payments.PrepareCancellationAsync(r, ct, existingPayments.GetValueOrDefault(r.Id), true);
            var from = r.Status;
            r.Status = ReservationStatus.Cancelled;
            r.StatusDefinition = cancelledDefinition;
            r.StatusDefinitionId = cancelledDefinition.Id;
            r.CancellationReason = "Termin je istekao prije potvrde.";
            db.ReservationStatusHistories.Add(new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = r.Id, FromStatus = from, ToStatus = r.Status, Reason = r.CancellationReason });
            await StatusNotificationAsync(r, r.CancellationReason, ct);
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return expired.Count;
    }

    private async Task StatusNotificationAsync(Reservation r, string reason, CancellationToken ct)
    {
        var title = r.Status switch { ReservationStatus.Confirmed => "Rezervacija potvrđena", ReservationStatus.Cancelled => "Rezervacija otkazana", ReservationStatus.Completed => "Tretman završen", _ => "Promjena statusa rezervacije" };
        var local = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(r.StartAtUtc, DateTimeKind.Utc), TimeZoneInfo.FindSystemTimeZoneById(config.TimeZone));
        var text = $"{r.Service.Name}, {local:dd.MM.yyyy. HH:mm}. {title}. Razlog: {reason}";
        await notifications.AddAsync(r.UserId, "ReservationStatusChanged", title, text, ct);
    }

    public async Task<IReadOnlyList<ReservationResponse>> ClientResponsesAsync(IReadOnlyList<Reservation> rows, CancellationToken ct)
    {
        var ids = rows.Select(x => x.Id).ToList();
        var paid = await db.Payments.AsNoTracking().Include(x => x.Transactions).Where(x => ids.Contains(x.ReservationId)).ToDictionaryAsync(x => x.ReservationId, ct);
        var reviewed = (await db.Reviews.AsNoTracking().Where(x => ids.Contains(x.ReservationId)).Select(x => x.ReservationId).ToListAsync(ct)).ToHashSet();
        var definitions = await db.ReservationStatuses.AsNoTracking().ToDictionaryAsync(x => x.Id, x => x.Name, ct);
        return rows.Select(r => {
            paid.TryGetValue(r.Id, out var p);
            var net = p?.PaidAtUtc != null ? p.Transactions.Sum(x => x.Kind == "Refund" ? -x.Amount : x.Amount) : 0;
            return new ReservationResponse(r.Id, r.Service.Name, r.StartAtUtc, r.EndAtUtc, r.PaymentMethod, r.Status, r.CancellationReason, p?.Status.ToString() ?? "Unpaid", p?.Status == PaymentStatus.Paid, reviewed.Contains(r.Id), r.TotalAmount, net, Math.Max(0, r.TotalAmount - net), r.Currency, definitions.GetValueOrDefault(r.StatusDefinitionId) ?? r.Status.ToString());
        }).ToList();
    }

    public async Task<IReadOnlyList<StaffReservationResponse>> StaffResponsesAsync(IReadOnlyList<Reservation> rows, CancellationToken ct)
    {
        var ids = rows.Select(x => x.Id).ToList();
        var paid = await db.Payments.AsNoTracking().Where(x => ids.Contains(x.ReservationId)).ToDictionaryAsync(x => x.ReservationId, ct);
        var definitions = await db.ReservationStatuses.AsNoTracking().ToDictionaryAsync(x => x.Id, x => x.Name, ct);
        return rows.Select(r => { paid.TryGetValue(r.Id, out var p); return new StaffReservationResponse(r.Id, r.UserId, $"{r.User.FirstName} {r.User.LastName}", r.User.Email, r.Service.Name, r.StartAtUtc, r.EndAtUtc, r.PaymentMethod, r.Status, r.CancellationReason, p?.Status.ToString() ?? "Unpaid", p?.Amount, p?.Currency, p?.PaidAtUtc, definitions.GetValueOrDefault(r.StatusDefinitionId) ?? r.Status.ToString()); }).ToList();
    }

    private Guid UserId() => Guid.Parse(http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private void RequireStaff() { if (!http.HttpContext!.User.IsInRole("Admin") && !http.HttpContext.User.IsInRole("Owner")) throw new UnauthorizedException("Ova akcija zahtijeva vlasničku ili administratorsku ulogu."); }
}
