using BeautyStudio.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Data;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(BeautyStudioDbContext db, CancellationToken cancellationToken, bool demoData = false)
    {
        await db.Database.MigrateAsync(cancellationToken);
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var existingNames = (await db.ServiceCategories.Select(x => x.Name).ToListAsync(cancellationToken)).ToHashSet();
        foreach (var name in new[] { "Nokti", "Obrve", "Trepavice", "Frizura", "Makeup", "Depilacija" })
            if (!existingNames.Contains(name)) db.ServiceCategories.Add(new ServiceCategory { Name = name });
        await db.SaveChangesAsync(cancellationToken);
        if (!await db.Services.AnyAsync(cancellationToken))
        {
            var categories = await db.ServiceCategories.ToDictionaryAsync(x => x.Name, x => x.Id, cancellationToken);
            var initial = new (string Name, decimal Price, int Duration, string Category)[]
            {
                ("Geliranje noktiju", 25, 60, "Nokti"), ("Korekcija obrvica", 15, 30, "Obrve"),
                ("Nadogradnja trepavica", 70, 90, "Trepavice"), ("Šišanje i feniranje", 35, 45, "Frizura"),
                ("Večernji makeup", 60, 90, "Makeup"), ("Depilacija nogu", 40, 60, "Depilacija")
            };
            db.Services.AddRange(initial.Select(x => new BeautyService { Name = x.Name, Description = "Profesionalni tretman: " + x.Name + ".", Price = x.Price, DurationMinutes = x.Duration, CategoryId = categories[x.Category] }));
        }

        if (demoData && !await db.Users.AnyAsync(cancellationToken))
        {
            db.Users.AddRange(
                CreateUser("desktop", "ivana.kovac@example.com", "Ivana", "Kovač", UserRole.Owner),
                CreateUser("mobile", "lea.maric@example.com", "Lea", "Marić", UserRole.Client),
                CreateUser("admin", "martina.horvat@example.com", "Martina", "Horvat", UserRole.Admin));
            db.Users.AddRange(
                CreateUser("petra.peric", "petra.peric@example.com", "Petra", "Perić", UserRole.Client),
                CreateUser("zala.zalac", "zala.zalac@example.com", "Zala", "Zalać", UserRole.Client),
                CreateUser("lejla.hadzic", "lejla.hadzic@example.com", "Lejla", "Hadžić", UserRole.Client),
                CreateUser("ana.kovac", "ana.kovac@example.com", "Ana", "Kovač", UserRole.Client),
                CreateUser("nina.juric", "nina.juric@example.com", "Nina", "Jurić", UserRole.Client),
                CreateUser("ema.basic", "ema.basic@example.com", "Ema", "Bašić", UserRole.Client));
        }

        await db.SaveChangesAsync(cancellationToken);
        await EnsureExpandedCatalogAsync(db, cancellationToken);
        await EnsureContentAsync(db, cancellationToken);
        if (demoData)
        {
            var studio = await db.StudioAbouts.SingleOrDefaultAsync(cancellationToken);
            if (studio != null)
            {
                if (string.IsNullOrWhiteSpace(studio.Address)) studio.Address = "Maršala Tita 10";
                if (string.IsNullOrWhiteSpace(studio.Phone)) studio.Phone = "+387 36 555 010";
                if (string.IsNullOrWhiteSpace(studio.Email)) studio.Email = "info@beautystudio.ba";
                studio.CityId ??= 1;
            }
        }
        await db.SaveChangesAsync(cancellationToken);
        var studioId = await db.StudioAbouts.Select(x => x.Id).SingleAsync(cancellationToken);
        await db.FaqEntries.Where(x => x.StudioAboutId == null).ExecuteUpdateAsync(x => x.SetProperty(f => f.StudioAboutId, studioId), cancellationToken);
        if (demoData) await EnsureDemoReservationsAsync(db, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
    }

    private static async Task EnsureDemoReservationsAsync(BeautyStudioDbContext db, CancellationToken ct)
    {
        if (await db.Reservations.AnyAsync(ct)) return;
        var client = await db.Users.SingleOrDefaultAsync(x => x.Username == "mobile", ct);
        var owner = await db.Users.SingleOrDefaultAsync(x => x.Username == "desktop", ct);
        if (client == null || owner == null) return;
        var services = await db.Services.Where(x => x.IsActive).OrderBy(x => x.Id).Take(12).ToListAsync(ct);
        var statuses = await db.ReservationStatuses.Where(x => x.IsActive).OrderBy(x => x.Id).ToListAsync(ct);
        int StatusId(ReservationStatus status) => statuses.First(x => x.Code == status).Id;
        var notificationTypes = await db.NotificationTypes.ToDictionaryAsync(x => x.Code, x => x.Id, ct);
        var now = DateTime.UtcNow;
        for (var i = 0; i < services.Count; i++)
        {
            var service = services[i];
            var start = now.Date.AddDays(-20 + i).AddHours(8);
            var r = new Reservation { Id = Guid.NewGuid(), UserId = client.Id, ServiceId = service.Id, StartAtUtc = start, EndAtUtc = start.AddMinutes(service.DurationMinutes), Status = ReservationStatus.Completed, StatusDefinitionId = StatusId(ReservationStatus.Completed), TotalAmount = service.Price, PaymentMethod = ReservationPaymentMethod.OnSite, Currency = "bam", CreatedAtUtc = start.AddDays(-2) };
            db.Reservations.Add(r);
            db.ReservationStatusHistories.AddRange(new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = r.Id, ChangedByUserId = client.Id, ToStatus = ReservationStatus.Pending, Reason = "Rezervacija termina preko aplikacije.", ChangedAtUtc = r.CreatedAtUtc }, new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = r.Id, ChangedByUserId = owner.Id, FromStatus = ReservationStatus.Pending, ToStatus = ReservationStatus.Confirmed, Reason = "Termin potvrđen nakon dogovora s klijenticom.", ChangedAtUtc = start.AddDays(-1) }, new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = r.Id, ChangedByUserId = owner.Id, FromStatus = ReservationStatus.Confirmed, ToStatus = ReservationStatus.Completed, Reason = "Tretman je završen i naplaćen u salonu.", ChangedAtUtc = r.EndAtUtc });
            var payment = new Payment { Id = Guid.NewGuid(), ReservationId = r.Id, Provider = "OnSite", Amount = r.TotalAmount, Currency = r.Currency, Status = PaymentStatus.Paid, PaidAtUtc = r.EndAtUtc, CreatedAtUtc = r.EndAtUtc };
            db.Payments.Add(payment);
            db.PaymentTransactions.Add(new PaymentTransaction { Id = Guid.NewGuid(), PaymentId = payment.Id, Kind = "Charge", ProviderId = "demo-onsite-" + r.Id, Amount = payment.Amount, OccurredAtUtc = r.EndAtUtc });
            if (i < 6) db.Reviews.Add(new Review { Id = Guid.NewGuid(), UserId = client.Id, ReservationId = r.Id, ServiceId = service.Id, Rating = 4 + i % 2, Comment = "Prijatan ambijent i uredno obavljen tretman.", CreatedAtUtc = r.EndAtUtc.AddHours(2) });
            db.UserActivities.Add(new UserActivity { Id = Guid.NewGuid(), UserId = client.Id, ServiceId = service.Id, CategoryId = service.CategoryId, Type = UserActivityType.ServiceReserved, CreatedAtUtc = r.CreatedAtUtc });
        }
        foreach (var (offset, status) in new[] { (2, ReservationStatus.Pending), (3, ReservationStatus.Confirmed) })
        {
            var service = services.First();
            var start = now.Date.AddDays(offset).AddHours(8);
            var r = new Reservation { Id = Guid.NewGuid(), UserId = client.Id, ServiceId = service.Id, StartAtUtc = start, EndAtUtc = start.AddMinutes(service.DurationMinutes), Status = status, StatusDefinitionId = StatusId(status), TotalAmount = service.Price, PaymentMethod = ReservationPaymentMethod.OnSite, Currency = "bam" };
            db.Reservations.Add(r);
            db.ReservationStatusHistories.Add(new ReservationStatusHistory { Id = Guid.NewGuid(), ReservationId = r.Id, ChangedByUserId = owner.Id, ToStatus = status, Reason = "Zakazan termin za odabrani tretman." });
        }
        db.NotificationOutbox.Add(new NotificationOutbox { Id = Guid.NewGuid(), UserId = client.Id, NotificationTypeId = notificationTypes["ReservationStatusChanged"], Title = "Dobrodošli u BeautyStudio", Message = "Svoje termine, plaćanja i novosti salona možete pratiti na jednom mjestu." });
        db.NotificationOutbox.Add(new NotificationOutbox { Id = Guid.NewGuid(), UserId = owner.Id, NotificationTypeId = notificationTypes["ReservationCreated"], Title = "Pregled poslovanja salona", Message = "Na dashboardu pratite rezervacije, naplate i najtraženije usluge." });
        await db.SaveChangesAsync(ct);
    }

    private static AppUser CreateUser(string username, string email, string firstName, string lastName, UserRole role) => new()
    {
        Id = Guid.NewGuid(), Username = username, Email = email, FirstName = firstName, LastName = lastName,
        PasswordHash = BCrypt.Net.BCrypt.HashPassword("test"), Role = role
    };

    private static async Task EnsureExpandedCatalogAsync(BeautyStudioDbContext db, CancellationToken ct)
    {
        var categories = await db.ServiceCategories.ToDictionaryAsync(x => x.Name, x => x.Id, ct);
        var existing = (await db.Services.Select(x => x.Name).ToListAsync(ct)).ToHashSet();
        var additions = new (string Name, string Description, decimal Price, int Duration, string Category)[]
        {
            ("Klasična manikura", "Njega i oblikovanje prirodnih noktiju.", 20, 45, "Nokti"), ("Lakiranje noktiju na nogama", "Oblikovanje i lakiranje noktiju na nogama.", 15, 30, "Nokti"), ("Klasična pedikura", "Njega stopala i noktiju.", 35, 60, "Nokti"), ("Nail art", "Dekoracija noktiju po odabranom dizajnu.", 15, 30, "Nokti"),
            ("Čupanje obrva", "Precizno oblikovanje obrva pincetom ili koncem.", 12, 20, "Obrve"), ("Farbanje obrva", "Bojenje obrva za izraženiji izgled.", 15, 20, "Obrve"), ("Laminacija obrva", "Oblikovanje i fiksiranje dlačica obrva.", 45, 45, "Obrve"),
            ("Lash lift i farbanje", "Podizanje i naglašavanje prirodnih trepavica.", 50, 60, "Trepavice"), ("Korekcija trepavica", "Dopuna i korekcija postojećih ekstenzija.", 35, 60, "Trepavice"),
            ("Feniranje", "Pranje i stilizovanje kose feniranjem.", 25, 30, "Frizura"), ("Farbanje kose", "Profesionalno farbanje u odabranu nijansu.", 80, 120, "Frizura"), ("Balayage", "Postepeno posvjetljivanje kose prirodnim prijelazom.", 120, 180, "Frizura"), ("Keratinski tretman", "Tretman za zaglađivanje i njegu kose.", 100, 150, "Frizura"),
            ("Svadbeni makeup", "Dugotrajan makeup prilagođen vjenčanju i fotografisanju.", 120, 120, "Makeup"), ("Makeup za izlazak", "Večernji makeup za posebne prilike.", 55, 75, "Makeup"), ("Probni svadbeni makeup", "Konsultacija i proba svadbenog makeup izgleda.", 60, 75, "Makeup"),
            ("Depilacija pazuha", "Depilacija osjetljive regije pazuha.", 15, 20, "Depilacija"), ("Bikini depilacija", "Depilacija bikini regije.", 30, 45, "Depilacija"), ("Depilacija cijelih nogu", "Kompletna depilacija nogu.", 50, 75, "Depilacija")
        };
        db.Services.AddRange(additions.Where(x => !existing.Contains(x.Name)).Select(x => new BeautyService { Name = x.Name, Description = x.Description, Price = x.Price, DurationMinutes = x.Duration, CategoryId = categories[x.Category] }));
    }

    private static async Task EnsureContentAsync(BeautyStudioDbContext db, CancellationToken ct)
    {
        var galleryTitles = (await db.GalleryItems.Select(x => x.Title).ToListAsync(ct)).ToHashSet();
        var gallery = new (string Title, string Url, string Category, string Description)[]
        {
            ("Elegantni gel nokti", "https://images.unsplash.com/photo-1604654894610-df63bc536371?auto=format&fit=crop&w=900&q=80", "Nokti", "Inspiracija za uredan manikir i izbor nijanse za svakodnevne prilike."),
            ("Svadbeni makeup", "https://images.unsplash.com/photo-1487412912498-0447578fcca8?auto=format&fit=crop&w=900&q=80", "Makeup", "Ideja za svečano šminkanje koje naglašava oči i prati prirodan ten."),
            ("Njega i stilizovanje kose", "https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=900&q=80", "Frizura", "Njegovana kosa i završno stilizovanje za poseban događaj.")
        };
        var categories = await db.ServiceCategories.ToDictionaryAsync(x => x.Name, x => x.Id, ct);
        db.GalleryItems.AddRange(gallery.Where(x => !galleryTitles.Contains(x.Title)).Select(x => new GalleryItem { Id = Guid.NewGuid(), Title = x.Title, Description = x.Description, ImageUrl = x.Url, CategoryId = categories[x.Category], IsActive = true }));
        var blogTitles = (await db.BlogPosts.Select(x => x.Title).ToListAsync(ct)).ToHashSet();
        var blogs = new (string Title, string Content)[]
        {
            ("Kako produžiti trajanje gel manikure", "Za uredan izgled noktiju koristite ulje za zanoktice, zaštitite ruke pri čišćenju i ne koristite nokte kao alat."),
            ("Priprema kože za svečani makeup", "Nježna hidratacija i lagana priprema kože pomažu da makeup izgleda svježe i postojano tokom cijelog događaja."),
            ("Plan njege prije vjenčanja", "Probni makeup, oblikovanje obrva i njega noktiju najbolje je planirati unaprijed kako bi završni izgled bio bez stresa."),
            ("Njega kose nakon farbanja", "Koristite proizvode za obojenu kosu, masku jednom sedmično i izbjegavajte prečesto toplotno stilizovanje."),
            ("Obrve koje pristaju vašem licu", "Profesionalno oblikovanje prati prirodni luk obrve i može naglasiti pogled bez pretjeranog stanjivanja dlačica.")
        };
        db.BlogPosts.AddRange(blogs.Where(x => !blogTitles.Contains(x.Title)).Select(x => new BlogPost { Id = Guid.NewGuid(), Title = x.Title, Content = x.Content, CategoryId = categories[x.Title.Contains("manikure") ? "Nokti" : x.Title.Contains("kose") ? "Frizura" : x.Title.Contains("Obrve") ? "Obrve" : "Makeup"], ImageUrl = gallery.First(g => g.Category == (x.Title.Contains("manikure") ? "Nokti" : x.Title.Contains("kose") ? "Frizura" : "Makeup")).Url, IsPublished = true, PublishedAtUtc = DateTime.UtcNow }));
        if (!await db.StudioAbouts.AnyAsync(ct)) db.StudioAbouts.Add(new StudioAbout { Title = "BeautyStudio — naša priča", Content = "BeautyStudio nudi profesionalnu njegu noktiju, obrva, trepavica, kose i makeup tretmane. Naš tim individualno pristupa svakom klijentu.", ImageUrl = gallery[2].Url, Address = "Maršala Tita 10", CityId = 1, Phone = "+387 36 555 010", Email = "info@beautystudio.ba", FoundedYear = 2020 });
        if (!await db.FaqEntries.AnyAsync(ct)) db.FaqEntries.AddRange(new FaqEntry { Id = Guid.NewGuid(), Question = "Kako mogu rezervisati termin?", Answer = "Odaberite uslugu, datum i slobodno vrijeme. Za potvrdu rezervacije prijavite se na svoj nalog.", SortOrder = 1, IsActive = true }, new FaqEntry { Id = Guid.NewGuid(), Question = "Koji su načini plaćanja?", Answer = "Dostupno je plaćanje na mjestu i kartično plaćanje. Postavke salona određuju da li se karticom plaća avans ili puni iznos.", SortOrder = 2, IsActive = true }, new FaqEntry { Id = Guid.NewGuid(), Question = "Mogu li otkazati termin?", Answer = "Aktivan termin možete otkazati u Mojim terminima uz razlog. Za plaćenu rezervaciju sistem pokreće povrat sredstava preko Stripea.", SortOrder = 3, IsActive = true });
    }
}
