using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using System.Security.Claims;

namespace BeautyStudio.Api.Services;

public sealed class ReportService(BeautyStudioDbContext db)
{
    public async Task<byte[]> ReservationReportAsync(DateOnly from, DateOnly to, CancellationToken cancellationToken)
    {
        var (start, end) = ValidateAndConvertPeriod(from, to);
        var reservations = await db.Reservations.AsNoTracking().Where(item => item.StartAtUtc >= start && item.StartAtUtc < end).OrderBy(item => item.StartAtUtc)
            .Select(item => new ReservationRow(item.User.FirstName + " " + item.User.LastName, item.Service.Name, item.StartAtUtc, item.StatusDefinition.Name))
            .ToListAsync(cancellationToken);
        return Document.Create(document => document.Page(page =>
        {
            page.Margin(30);
            page.Header().Text("BeautyStudio - Izvještaj rezervacija").FontSize(20).SemiBold();
            page.Content().Column(column =>
            {
                column.Spacing(12);
                column.Item().Text($"Period: {from:dd.MM.yyyy.} - {to:dd.MM.yyyy.}");
                column.Item().Text($"Ukupno rezervacija: {reservations.Count}").SemiBold();
                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(columns => { columns.RelativeColumn(2); columns.RelativeColumn(2); columns.RelativeColumn(2); columns.RelativeColumn(1); });
                    table.Header(header => { header.Cell().Element(HeaderCell).Text("Klijent"); header.Cell().Element(HeaderCell).Text("Usluga"); header.Cell().Element(HeaderCell).Text("Termin"); header.Cell().Element(HeaderCell).Text("Status"); });
                    foreach (var item in reservations) { table.Cell().Element(BodyCell).Text(item.ClientName); table.Cell().Element(BodyCell).Text(item.ServiceName); table.Cell().Element(BodyCell).Text(ToZagreb(item.StartAtUtc).ToString("dd.MM.yyyy. HH:mm")); table.Cell().Element(BodyCell).Text(StatusLabel(item.Status)); }
                });
            });
            page.Footer().AlignCenter().Text(text => { text.Span("BeautyStudio · Generisano "); text.Span(ToZagreb(DateTime.UtcNow).ToString("dd.MM.yyyy. HH:mm")); });
        })).GeneratePdf();
    }

    public async Task<byte[]> PopularServicesReportAsync(DateOnly from, DateOnly to, CancellationToken cancellationToken)
    {
        var (start, end) = ValidateAndConvertPeriod(from, to);
        var rows = await db.Services.AsNoTracking()
            .Select(service => new { service.Name, ReservationCount = db.Reservations.Count(reservation => reservation.ServiceId == service.Id && reservation.StartAtUtc >= start && reservation.StartAtUtc < end), CompletedCount = db.Reservations.Count(reservation => reservation.ServiceId == service.Id && reservation.StartAtUtc >= start && reservation.StartAtUtc < end && reservation.Status == ReservationStatus.Completed) })
            .Where(item => item.ReservationCount > 0).OrderByDescending(item => item.ReservationCount).ThenByDescending(item => item.CompletedCount).ThenBy(item => item.Name).ToListAsync(cancellationToken);
        return Document.Create(document => document.Page(page =>
        {
            page.Margin(30);
            page.Header().Text("BeautyStudio - Najtraženije usluge").FontSize(20).SemiBold();
            page.Content().Column(column =>
            {
                column.Spacing(12);
                column.Item().Text($"Period: {from:dd.MM.yyyy.} - {to:dd.MM.yyyy.}");
                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(columns => { columns.RelativeColumn(3); columns.RelativeColumn(); columns.RelativeColumn(2); });
                    table.Header(header => { header.Cell().Element(HeaderCell).Text("Usluga"); header.Cell().Element(HeaderCell).Text("Rezervacije"); header.Cell().Element(HeaderCell).Text("Završeni tretmani"); });
                    foreach (var item in rows) { table.Cell().Element(BodyCell).Text(item.Name); table.Cell().Element(BodyCell).Text(item.ReservationCount.ToString()); table.Cell().Element(BodyCell).Text(item.CompletedCount.ToString()); }
                });
            });
            page.Footer().AlignCenter().Text(text => { text.Span("BeautyStudio · Generisano "); text.Span(ToZagreb(DateTime.UtcNow).ToString("dd.MM.yyyy. HH:mm")); });
        })).GeneratePdf();
    }

    public async Task<byte[]> PaymentReportAsync(DateOnly from, DateOnly to, CancellationToken cancellationToken)
    {
        var (start, end) = ValidateAndConvertPeriod(from, to);
        var rows = await db.PaymentTransactions.AsNoTracking().Where(x => x.OccurredAtUtc >= start && x.OccurredAtUtc < end).OrderBy(x => x.OccurredAtUtc)
            .Select(x => new { Client = x.Payment.Reservation.User.FirstName + " " + x.Payment.Reservation.User.LastName, Service = x.Payment.Reservation.Service.Name, x.Amount, x.Kind, x.OccurredAtUtc, x.Payment.Currency, Method = x.Kind == "OnSiteCharge" ? "Na mjestu" : x.Payment.Provider }).ToListAsync(cancellationToken);
        return Document.Create(document => document.Page(page => {
            page.Size(PageSizes.A4.Landscape()); page.Margin(30);
            page.Header().Text("BeautyStudio - Plaćanja i povrati").FontSize(20).SemiBold();
            page.Content().Column(column => {
                column.Spacing(12);
                column.Item().Text($"Period: {from:dd.MM.yyyy.} - {to:dd.MM.yyyy.}");
                column.Item().Text($"Neto naplaćeno: {rows.Sum(x => x.Kind == "Refund" ? -x.Amount : x.Amount):0.00} | Transakcija: {rows.Count}");
                column.Item().Table(table => {
                    table.ColumnsDefinition(c => { c.RelativeColumn(2); c.RelativeColumn(2); c.RelativeColumn(); c.RelativeColumn(); c.RelativeColumn(); c.RelativeColumn(2); });
                    table.Header(h => { foreach (var title in new[] { "Klijent", "Usluga", "Iznos", "Način", "Vrsta", "Datum transakcije" }) h.Cell().Element(HeaderCell).Text(title); });
                    foreach (var row in rows) {
                        table.Cell().Element(BodyCell).Text(row.Client); table.Cell().Element(BodyCell).Text(row.Service);
                        table.Cell().Element(BodyCell).Text($"{(row.Kind == "Refund" ? -row.Amount : row.Amount):0.00} {row.Currency.ToUpperInvariant()}");
                        table.Cell().Element(BodyCell).Text(row.Method); table.Cell().Element(BodyCell).Text(row.Kind == "Refund" ? "Povrat" : "Naplata");
                        table.Cell().Element(BodyCell).Text(ToZagreb(row.OccurredAtUtc).ToString("dd.MM.yyyy. HH:mm"));
                    }
                });
            });
            page.Footer().AlignCenter().Text("BeautyStudio - Evidentirane transakcije");
        })).GeneratePdf();
    }

    public async Task<byte[]> PaymentReceiptAsync(Guid reservationId, ClaimsPrincipal user, CancellationToken ct)
    {
        var id = Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var item = await db.Payments.AsNoTracking().Include(x => x.Transactions).Include(x => x.Reservation).ThenInclude(x => x.User).Include(x => x.Reservation).ThenInclude(x => x.Service).SingleOrDefaultAsync(x => x.ReservationId == reservationId, ct) ?? throw new NotFoundException("Potvrda plaćanja nije pronađena.");
        if (item.Reservation.UserId != id && !user.IsInRole("Admin") && !user.IsInRole("Owner")) throw new NotFoundException("Potvrda plaćanja nije pronađena.");
        if (item.PaidAtUtc == null) throw new BusinessException("Potvrda je dostupna nakon uspješne naplate.");
        return Document.Create(d => d.Page(p => {
            p.Margin(40); p.Header().Text("BeautyStudio - Potvrda plaćanja").FontSize(22).SemiBold();
            p.Content().Column(c => {
                c.Spacing(14);
                c.Item().Text($"Klijent: {item.Reservation.User.FirstName} {item.Reservation.User.LastName}");
                c.Item().Text($"Usluga: {item.Reservation.Service.Name}");
                c.Item().Text($"Termin: {ToZagreb(item.Reservation.StartAtUtc):dd.MM.yyyy. HH:mm}");
                c.Item().Text($"Ukupna cijena rezervacije: {item.Reservation.TotalAmount:0.00} {item.Currency.ToUpperInvariant()}");
                foreach (var t in item.Transactions.OrderBy(x => x.OccurredAtUtc)) c.Item().Text($"{ToZagreb(t.OccurredAtUtc):dd.MM.yyyy. HH:mm} | {(t.Kind == "Refund" ? "Povrat" : "Naplata")} | {t.Amount:0.00} {item.Currency.ToUpperInvariant()} | {t.ProviderId}");
                c.Item().Text($"Neto plaćeno: {item.Transactions.Sum(x => x.Kind == "Refund" ? -x.Amount : x.Amount):0.00} {item.Currency.ToUpperInvariant()}").SemiBold();
            });
            p.Footer().Text("Potvrda evidentirane transakcije. Stripe sandbox služi za demonstraciju i ne naplaćuje stvarna sredstva.").FontSize(9);
        })).GeneratePdf();
    }

    private static IContainer HeaderCell(IContainer container) => container.Background(Colors.Pink.Darken2).Padding(6).DefaultTextStyle(style => style.FontColor(Colors.White).SemiBold());
    private static IContainer BodyCell(IContainer container) => container.BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingVertical(5).PaddingHorizontal(3);
    private static (DateTime Start, DateTime End) ValidateAndConvertPeriod(DateOnly from, DateOnly to)
    {
        if (to < from) throw new BusinessException("Datum završetka ne može biti prije datuma početka.");
        var zone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Zagreb");
        var start = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(from.ToDateTime(TimeOnly.MinValue), DateTimeKind.Unspecified), zone);
        var end = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(to.AddDays(1).ToDateTime(TimeOnly.MinValue), DateTimeKind.Unspecified), zone);
        return (start, end);
    }
    private static DateTime ToZagreb(DateTime utc) => TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), TimeZoneInfo.FindSystemTimeZoneById("Europe/Zagreb"));
    private static string StatusLabel(string status) => status switch { "Pending" => "Na čekanju", "Confirmed" => "Potvrđeno", "Cancelled" => "Otkazano", "Completed" => "Završeno", _ => status };
    private sealed record ReservationRow(string ClientName, string ServiceName, DateTime StartAtUtc, string Status);
    private sealed record PopularServiceRow(string Name, int ReservationCount, int CompletedCount);
    private sealed record PaymentRow(string Client, string Service, decimal Amount, string Currency, string Status, DateTime CreatedAtUtc, DateTime? PaidAtUtc);
}
