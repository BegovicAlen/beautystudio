using System.Security.Claims;
using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Contracts.Payments;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;
using Stripe;
using Stripe.Checkout;

namespace BeautyStudio.Api.Services;

public sealed class PaymentService(BeautyStudioDbContext db, IHttpContextAccessor http, AppConfiguration config, NotificationComposer notifications, ILogger<PaymentService> logger)
{
    private Guid UserId() => Guid.Parse(http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private StripeClient Client()
    {
        if (string.IsNullOrWhiteSpace(config.StripeSecretKey) || !config.StripeSecretKey.StartsWith("sk_test_"))
            throw new BusinessException("Stripe sandbox nije konfigurisan. Administrator treba postaviti STRIPE_SECRET_KEY test ključ.");
        return new StripeClient(config.StripeSecretKey);
    }

    public async Task<CheckoutResponse> CheckoutAsync(Guid reservationId, CancellationToken ct, bool mobile = false)
    {
        await using var tx = await BookingLock.BeginAsync(db, ct);
        var r = await db.Reservations.Include(x => x.Service).SingleOrDefaultAsync(x => x.Id == reservationId && x.UserId == UserId(), ct) ?? throw new NotFoundException("Rezervacija nije pronađena.");
        if (r.PaymentMethod != ReservationPaymentMethod.Card || r.Status is ReservationStatus.Cancelled or ReservationStatus.Completed || r.EndAtUtc <= DateTime.UtcNow)
            throw new BusinessException("Kartično plaćanje je dostupno samo za aktivne buduće rezervacije.");
        var p = await db.Payments.SingleOrDefaultAsync(x => x.ReservationId == r.Id, ct);
        if (p?.Status is PaymentStatus.Paid or PaymentStatus.Refunded or PaymentStatus.RefundPending or PaymentStatus.PartiallyRefunded) throw new BusinessException("Ova rezervacija je već plaćena ili je u toku povrat sredstava.");
        var sessions = new SessionService(Client());
        if (!string.IsNullOrEmpty(p?.StripeCheckoutSessionId))
        {
            var existing = await sessions.GetAsync(p.StripeCheckoutSessionId, cancellationToken: ct);
            if (existing.PaymentStatus == "paid") { await ApplySessionAsync(p, existing, ct); await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); throw new BusinessException("Plaćanje je već evidentirano. Osvježite rezervacije."); }
            if (existing.Status == "open") { await tx.CommitAsync(ct); return new CheckoutResponse(existing.Url, p.Status.ToString()); }
        }
        p ??= new Payment { Id = Guid.NewGuid(), ReservationId = r.Id };
        if (db.Entry(p).State == EntityState.Detached) db.Payments.Add(p);
        p.Amount = decimal.Round(r.TotalAmount * r.DepositPercent / 100m, 2, MidpointRounding.AwayFromZero);
        p.Currency = r.Currency;
        var previousSession = p.StripeCheckoutSessionId ?? "initial";
        var url = (mobile ? config.PaymentMobileReturnBaseUrl : config.PaymentReturnBaseUrl).TrimEnd('/') + "/api/payments/return?reservationId=" + r.Id;
        try
        {
            var session = await sessions.CreateAsync(new SessionCreateOptions
            {
                Mode = "payment", SuccessUrl = url + "&result=success", CancelUrl = url + "&result=cancel",
                ClientReferenceId = r.Id.ToString(), Metadata = new() { ["reservationId"] = r.Id.ToString() },
                LineItems = [new SessionLineItemOptions { Quantity = 1, PriceData = new SessionLineItemPriceDataOptions { Currency = p.Currency, UnitAmount = (long)(p.Amount * 100), ProductData = new SessionLineItemPriceDataProductDataOptions { Name = r.Service.Name + (r.DepositPercent < 100 ? $" — avans {r.DepositPercent}%" : "") } } }],
            }, new RequestOptions { IdempotencyKey = $"checkout-{r.Id}-{previousSession}" }, ct);
            p.StripeCheckoutSessionId = session.Id;
            p.StripePaymentIntentId = null;
            p.Status = PaymentStatus.Pending;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return new CheckoutResponse(session.Url, p.Status.ToString());
        }
        catch (StripeException e) { logger.LogError(e, "Stripe checkout failed for reservation {ReservationId}.", r.Id); throw new BusinessException("Stripe trenutno ne može pokrenuti plaćanje. Pokušajte ponovo."); }
    }

    public async Task<PaymentResponse> VerifyAsync(Guid reservationId, CancellationToken ct)
    {
        await using var tx = await BookingLock.BeginAsync(db, ct);
        var p = await LoadAsync(reservationId, ct);
        if (p.Reservation.UserId != UserId()) throw new NotFoundException("Plaćanje nije pronađeno.");
        if (p.Provider == "Stripe" && p.Status is PaymentStatus.Pending or PaymentStatus.Expired or PaymentStatus.Failed)
            await ApplySessionAsync(p, await new SessionService(Client()).GetAsync(p.StripeCheckoutSessionId, cancellationToken: ct), ct);
        if (p.Status == PaymentStatus.RefundPending && p.StripeRefundId != null)
            await ApplyRefundAsync(p, await new RefundService(Client()).GetAsync(p.StripeRefundId, cancellationToken: ct), ct);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await ResponseAsync(reservationId, ct);
    }

    public async Task PrepareCancellationAsync(Reservation r, CancellationToken ct, Payment? loaded = null, bool preloaded = false)
    {
        var p = preloaded ? loaded : await db.Payments.Include(x => x.Reservation).ThenInclude(x => x.Service).SingleOrDefaultAsync(x => x.ReservationId == r.Id, ct);
        if (p == null || p.Status == PaymentStatus.Refunded) return;
        if (p.Provider == "Stripe" && p.Status == PaymentStatus.Pending && p.StripeCheckoutSessionId != null)
        {
            var service = new SessionService(Client());
            var session = await service.GetAsync(p.StripeCheckoutSessionId, cancellationToken: ct);
            if (session.Status == "open")
            {
                try { session = await service.ExpireAsync(session.Id, cancellationToken: ct); }
                catch (StripeException) { session = await service.GetAsync(session.Id, cancellationToken: ct); }
            }
            await ApplySessionAsync(p, session, ct);
        }
        if (p.Status is PaymentStatus.Paid or PaymentStatus.RefundPending or PaymentStatus.PartiallyRefunded) await RequestRefundAsync(p, ct);
    }

    private async Task RequestRefundAsync(Payment p, CancellationToken ct)
    {
        if (p.Status == PaymentStatus.Refunded) return;
        if (p.Provider != "Stripe" || p.StripePaymentIntentId == null) throw new BusinessException("Povrat ovog plaćanja nije dostupan preko Stripea.");
        try
        {
            var service = new RefundService(Client());
            var remaining = p.Amount - p.RefundedAmount;
            var refund = p.StripeRefundId == null || p.Status == PaymentStatus.PartiallyRefunded
                ? await service.CreateAsync(new RefundCreateOptions { PaymentIntent = p.StripePaymentIntentId, Amount = (long)(remaining * 100), Reason = "requested_by_customer", Metadata = new() { ["reservationId"] = p.ReservationId.ToString() } }, new RequestOptions { IdempotencyKey = "refund-" + p.Id + "-" + (long)(remaining * 100) }, ct)
                : await service.GetAsync(p.StripeRefundId, cancellationToken: ct);
            p.StripeRefundId = refund.Id;
            await ApplyRefundAsync(p, refund, ct);
        }
        catch (StripeException e) { logger.LogError(e, "Stripe refund failed for payment {PaymentId}.", p.Id); throw new BusinessException("Povrat sredstava nije potvrđen. Rezervacija ostaje aktivna; pokušajte ponovo."); }
    }

    private async Task ApplyRefundAsync(Payment p, Refund refund, CancellationToken ct)
    {
        if (p.Status == PaymentStatus.Refunded) return;
        if (refund.Status == "failed" || refund.Status == "canceled") throw new BusinessException("Stripe nije odobrio povrat. Kontaktirajte salon.");
        p.StripeRefundId = refund.Id;
        if (refund.Status != "succeeded") { p.Status = PaymentStatus.RefundPending; return; }
        if (await db.PaymentTransactions.AnyAsync(x => x.ProviderId == refund.Id, ct)) return;
        p.RefundedAmount += refund.Amount / 100m;
        p.Status = p.RefundedAmount >= p.Amount ? PaymentStatus.Refunded : PaymentStatus.PartiallyRefunded;
        p.RefundedAtUtc = DateTime.UtcNow;
        if (!await db.PaymentTransactions.AnyAsync(x => x.ProviderId == refund.Id, ct))
            db.PaymentTransactions.Add(new PaymentTransaction { Id = Guid.NewGuid(), PaymentId = p.Id, Kind = "Refund", ProviderId = refund.Id, Amount = refund.Amount / 100m });
        await notifications.AddAsync(p.Reservation.UserId, "PaymentRefunded", "Povrat sredstava potvrđen", $"Za {p.Reservation.Service.Name} vraćeno je {p.RefundedAmount:0.00} {p.Currency.ToUpperInvariant()}.", ct);
        await notifications.StaffAsync("PaymentRefunded", "Povrat sredstava", $"Povrat za rezervaciju {p.Reservation.Service.Name}: {p.RefundedAmount:0.00} {p.Currency.ToUpperInvariant()}.", ct);
    }

    private async Task ApplySessionAsync(Payment p, Session session, CancellationToken ct)
    {
        if (p.Status is PaymentStatus.Paid or PaymentStatus.Refunded or PaymentStatus.RefundPending or PaymentStatus.PartiallyRefunded) return;
        if (session.PaymentStatus == "paid")
        {
            if (session.ClientReferenceId != p.ReservationId.ToString() || session.Currency != p.Currency || session.AmountTotal != (long)(p.Amount * 100))
                throw new BusinessException("Podaci Stripe transakcije ne odgovaraju rezervaciji.");
            p.Status = PaymentStatus.Paid;
            p.StripePaymentIntentId = session.PaymentIntentId;
            p.PaidAtUtc = DateTime.UtcNow;
            if (!await db.PaymentTransactions.AnyAsync(x => x.ProviderId == session.PaymentIntentId, ct))
                db.PaymentTransactions.Add(new PaymentTransaction { Id = Guid.NewGuid(), PaymentId = p.Id, Kind = "Charge", ProviderId = session.PaymentIntentId, Amount = p.Amount });
            var intent = await new PaymentIntentService(Client()).GetAsync(session.PaymentIntentId, new PaymentIntentGetOptions { Expand = ["latest_charge"] }, cancellationToken: ct);
            p.ReceiptUrl = intent.LatestCharge?.ReceiptUrl;
            if (p.Reservation.Status == ReservationStatus.Pending)
            {
                p.Reservation.Status = ReservationStatus.Confirmed;
                p.Reservation.StatusDefinition = await StatusDefinitions.ResolveAsync(db, ReservationStatus.Confirmed, null, ct);
                p.Reservation.StatusDefinitionId = p.Reservation.StatusDefinition.Id;
                db.ReservationStatusHistories.Add(new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = p.ReservationId, FromStatus = ReservationStatus.Pending, ToStatus = ReservationStatus.Confirmed, Reason = "Rezervacija automatski potvrđena nakon Stripe plaćanja." });
                await notifications.AddAsync(p.Reservation.UserId, "ReservationStatusChanged", "Rezervacija potvrđena", $"Termin za {p.Reservation.Service.Name} potvrđen je nakon plaćanja.", ct);
            }
            await notifications.AddAsync(p.Reservation.UserId, "PaymentReceived", "Plaćanje potvrđeno", $"Plaćanje za {p.Reservation.Service.Name}: {p.Amount:0.00} {p.Currency.ToUpperInvariant()}.", ct);
            await notifications.StaffAsync("PaymentReceived", "Novo plaćanje", $"Plaćanje rezervacije {p.Reservation.Service.Name}: {p.Amount:0.00} {p.Currency.ToUpperInvariant()}.", ct);
            if (p.Reservation.Status == ReservationStatus.Cancelled) await RequestRefundAsync(p, ct);
        }
        else if (session.Status == "expired") p.Status = PaymentStatus.Expired;
    }

    public async Task RecordOnSiteAsync(Reservation r, CancellationToken ct)
    {
        var p = await db.Payments.SingleOrDefaultAsync(x => x.ReservationId == r.Id, ct);
        if (r.PaymentMethod == ReservationPaymentMethod.Card && p?.Status != PaymentStatus.Paid)
            throw new BusinessException("Kartično plaćanje mora biti potvrđeno prije završavanja tretmana.");
        if (p == null) { p = new Payment { Id = Guid.NewGuid(), ReservationId = r.Id, Amount = r.TotalAmount, Currency = r.Currency, Provider = "OnSite", Status = PaymentStatus.Paid, PaidAtUtc = DateTime.UtcNow }; db.Payments.Add(p); }
        var due = r.PaymentMethod == ReservationPaymentMethod.Card ? r.TotalAmount - p.Amount : p.Amount;
        if (due > 0)
        {
            var reference = "onsite-" + r.Id;
            if (!await db.PaymentTransactions.AnyAsync(x => x.ProviderId == reference, ct))
                db.PaymentTransactions.Add(new PaymentTransaction { Id = Guid.NewGuid(), PaymentId = p.Id, Kind = r.PaymentMethod == ReservationPaymentMethod.Card ? "OnSiteCharge" : "Charge", ProviderId = reference, Amount = due });
            await notifications.AddAsync(r.UserId, "PaymentReceived", "Plaćanje na mjestu evidentirano", $"Za {r.Service.Name} evidentirana je naplata na mjestu: {due:0.00} {r.Currency.ToUpperInvariant()}.", ct);
        }
    }

    public async Task HandleWebhookAsync(string json, string signature, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(config.StripeWebhookSecret)) throw new BusinessException("Stripe webhook nije konfigurisan.");
        Event stripeEvent;
        try { stripeEvent = EventUtility.ConstructEvent(json, signature, config.StripeWebhookSecret); }
        catch (StripeException) { throw new BusinessException("Stripe potpis poruke nije validan."); }
        await using var tx = await BookingLock.BeginAsync(db, ct);
        if (stripeEvent.Data.Object is Session session)
        {
            var p = await db.Payments.Include(x => x.Reservation).ThenInclude(x => x.Service).SingleOrDefaultAsync(x => x.StripeCheckoutSessionId == session.Id, ct);
            if (p != null)
            {
                if (stripeEvent.Type is "checkout.session.completed" or "checkout.session.async_payment_succeeded" or "checkout.session.expired") await ApplySessionAsync(p, session, ct);
                if (stripeEvent.Type == "checkout.session.async_payment_failed" && p.Status == PaymentStatus.Pending) p.Status = PaymentStatus.Failed;
            }
        }
        else if (stripeEvent.Data.Object is Refund refund)
        {
            var p = await db.Payments.Include(x => x.Reservation).ThenInclude(x => x.Service).SingleOrDefaultAsync(x => x.StripePaymentIntentId == refund.PaymentIntentId, ct);
            if (p != null) await ApplyRefundAsync(p, refund, ct);
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    private async Task<Payment> LoadAsync(Guid id, CancellationToken ct) => await db.Payments.Include(x => x.Reservation).ThenInclude(x => x.Service).SingleOrDefaultAsync(x => x.ReservationId == id, ct) ?? throw new NotFoundException("Evidencija plaćanja nije pronađena.");
    public Task<PaymentResponse> ResponseAsync(Guid id, CancellationToken ct) => db.Payments.AsNoTracking().Where(x => x.ReservationId == id).Select(PaymentProjection.Response).SingleAsync(ct);
}
