using BeautyStudio.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace BeautyStudio.Api.Data;

public sealed class BeautyStudioDbContext(DbContextOptions<BeautyStudioDbContext> options) : DbContext(options)
{
    public DbSet<ServiceCategory> ServiceCategories => Set<ServiceCategory>();
    public DbSet<BeautyService> Services => Set<BeautyService>();
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<ReservationStatusHistory> ReservationStatusHistories => Set<ReservationStatusHistory>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<GalleryItem> GalleryItems => Set<GalleryItem>();
    public DbSet<BlogPost> BlogPosts => Set<BlogPost>();
    public DbSet<UserActivity> UserActivities => Set<UserActivity>();
    public DbSet<ContactMessage> ContactMessages => Set<ContactMessage>();
    public DbSet<FaqEntry> FaqEntries => Set<FaqEntry>();
    public DbSet<StudioAbout> StudioAbouts => Set<StudioAbout>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<City> Cities => Set<City>();
    public DbSet<ReservationStatusDefinition> ReservationStatuses => Set<ReservationStatusDefinition>();
    public DbSet<NotificationType> NotificationTypes => Set<NotificationType>();
    public DbSet<NotificationOutbox> NotificationOutbox => Set<NotificationOutbox>();
    public DbSet<PaymentTransaction> PaymentTransactions => Set<PaymentTransaction>();
    public DbSet<RevokedToken> RevokedTokens => Set<RevokedToken>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var utcDateTimeConverter = new ValueConverter<DateTime, DateTime>(
            value => value.Kind == DateTimeKind.Utc ? value : value.ToUniversalTime(),
            value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
        modelBuilder.Entity<ServiceCategory>().HasIndex(category => category.Name).IsUnique();
        modelBuilder.Entity<ServiceCategory>().Property(x => x.Name).HasMaxLength(150);
        modelBuilder.Entity<City>().HasIndex(x => x.Name).IsUnique();
        modelBuilder.Entity<City>().Property(x => x.Name).HasMaxLength(100);
        modelBuilder.Entity<ReservationStatusDefinition>(entity => { entity.Property(x => x.Code).HasConversion<string>().HasMaxLength(32); entity.Property(x => x.Name).HasMaxLength(100); });
        modelBuilder.Entity<ReservationStatusDefinition>().HasData(new ReservationStatusDefinition { Id = 1, Code = ReservationStatus.Pending, Name = "Na čekanju" }, new ReservationStatusDefinition { Id = 2, Code = ReservationStatus.Confirmed, Name = "Potvrđeno" }, new ReservationStatusDefinition { Id = 3, Code = ReservationStatus.Cancelled, Name = "Otkazano" }, new ReservationStatusDefinition { Id = 4, Code = ReservationStatus.Completed, Name = "Završeno" });
        modelBuilder.Entity<City>().HasData(new City { Id = 1, Name = "Mostar" }, new City { Id = 2, Name = "Sarajevo" }, new City { Id = 3, Name = "Banja Luka" });
        modelBuilder.Entity<NotificationType>(entity => { entity.HasIndex(x => x.Code).IsUnique(); entity.Property(x => x.Code).HasMaxLength(60); entity.Property(x => x.Name).HasMaxLength(100); });
        modelBuilder.Entity<NotificationType>().HasData(new NotificationType { Id = 1, Code = "ReservationCreated", Name = "Nova rezervacija" }, new NotificationType { Id = 2, Code = "ReservationStatusChanged", Name = "Promjena statusa rezervacije" }, new NotificationType { Id = 3, Code = "PaymentReceived", Name = "Plaćanje" }, new NotificationType { Id = 4, Code = "PaymentRefunded", Name = "Povrat sredstava" }, new NotificationType { Id = 5, Code = "AccountSecurity", Name = "Sigurnost naloga" }, new NotificationType { Id = 1000, Code = "ContactMessageReceived", Name = "Nova poruka klijenta" }, new NotificationType { Id = 1001, Code = "ReviewCreated", Name = "Nova recenzija" });
        modelBuilder.Entity<NotificationOutbox>(entity => { entity.Property(x => x.Title).HasMaxLength(200); entity.Property(x => x.Message).HasMaxLength(2000); entity.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict); entity.HasOne(x => x.NotificationType).WithMany().HasForeignKey(x => x.NotificationTypeId).OnDelete(DeleteBehavior.Restrict); entity.HasIndex(x => x.PublishedAtUtc); });
        modelBuilder.Entity<PaymentTransaction>(entity => { entity.Property(x => x.Amount).HasPrecision(18, 2); entity.Property(x => x.ProviderId).HasMaxLength(255); entity.Property(x => x.Kind).HasMaxLength(20); entity.HasIndex(x => x.ProviderId).IsUnique(); entity.HasOne(x => x.Payment).WithMany(x => x.Transactions).HasForeignKey(x => x.PaymentId).OnDelete(DeleteBehavior.Restrict); });
        modelBuilder.Entity<RevokedToken>(entity => { entity.Property(x => x.Id).HasMaxLength(64); entity.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict); });
        modelBuilder.Entity<BeautyService>(entity =>
        {
            entity.Property(service => service.Name).HasMaxLength(150).IsRequired();
            entity.Property(service => service.Description).HasMaxLength(2000).IsRequired();
            entity.Property(service => service.Price).HasPrecision(18, 2);
            entity.HasOne(service => service.Category).WithMany(category => category.Services).HasForeignKey(service => service.CategoryId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<AppUser>(entity =>
        {
            entity.HasIndex(user => user.Email).IsUnique();
            entity.HasIndex(user => user.Username).IsUnique();
            entity.Property(user => user.Username).HasMaxLength(50).IsRequired();
            entity.Property(user => user.Email).HasMaxLength(254).IsRequired();
            entity.Property(user => user.ProfileImageUrl).HasMaxLength(2048);
            entity.Property(user => user.Role).HasConversion<string>();
            entity.Property(user => user.RecoveryCodeHash).HasMaxLength(64);
            entity.HasOne(x => x.City).WithMany().HasForeignKey(x => x.CityId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Reservation>(entity =>
        {
            entity.Property(reservation => reservation.Status).HasConversion<string>().HasMaxLength(32);
            entity.HasOne(x => x.StatusDefinition).WithMany().HasForeignKey(x => x.StatusDefinitionId).OnDelete(DeleteBehavior.Restrict);
            entity.Property(x => x.TotalAmount).HasPrecision(18, 2);
            entity.Property(x => x.DepositPercent).HasDefaultValue(100);
            entity.Property(x => x.Currency).HasMaxLength(3);
            entity.Property(reservation => reservation.PaymentMethod).HasConversion<string>();
            entity.Property(reservation => reservation.StartAtUtc).HasConversion(utcDateTimeConverter);
            entity.Property(reservation => reservation.EndAtUtc).HasConversion(utcDateTimeConverter);
            entity.Property(reservation => reservation.CreatedAtUtc).HasConversion(utcDateTimeConverter);
            entity.HasIndex(reservation => new { reservation.StartAtUtc, reservation.EndAtUtc });
            entity.HasOne(reservation => reservation.User).WithMany(user => user.Reservations).HasForeignKey(reservation => reservation.UserId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(reservation => reservation.Service).WithMany().HasForeignKey(reservation => reservation.ServiceId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<ReservationStatusHistory>(entity =>
        {
            entity.Property(history => history.FromStatus).HasConversion<string>();
            entity.Property(history => history.ToStatus).HasConversion<string>();
            entity.Property(history => history.ChangedAtUtc).HasConversion(utcDateTimeConverter);
            entity.HasOne(history => history.Reservation).WithMany().HasForeignKey(history => history.ReservationId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(history => history.ChangedBy).WithMany().HasForeignKey(history => history.ChangedByUserId).OnDelete(DeleteBehavior.Restrict).IsRequired(false);
        });
        modelBuilder.Entity<Notification>(entity =>
        {
            entity.Property(notification => notification.CreatedAtUtc).HasConversion(utcDateTimeConverter);
            entity.Property(notification => notification.Title).HasMaxLength(200).IsRequired();
            entity.Property(notification => notification.Message).HasMaxLength(2000).IsRequired();
            entity.HasOne(notification => notification.User).WithMany().HasForeignKey(notification => notification.UserId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(x => x.NotificationType).WithMany().HasForeignKey(x => x.NotificationTypeId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Review>(entity =>
        {
            entity.Property(review => review.Comment).HasMaxLength(2000);
            entity.HasIndex(review => review.ReservationId).IsUnique();
            entity.HasOne(review => review.Reservation).WithMany().HasForeignKey(review => review.ReservationId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(review => review.User).WithMany().HasForeignKey(review => review.UserId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(review => review.Service).WithMany().HasForeignKey(review => review.ServiceId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<GalleryItem>(entity => { entity.Property(item => item.Title).HasMaxLength(150).IsRequired(); entity.Property(item => item.Description).HasMaxLength(3000).IsRequired(); entity.Property(item => item.ImageUrl).HasMaxLength(2048).IsRequired(); entity.HasOne(x => x.ServiceCategory).WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict); });
        modelBuilder.Entity<BlogPost>(entity => { entity.Property(post => post.Title).HasMaxLength(200).IsRequired(); entity.Property(post => post.Content).HasMaxLength(10000).IsRequired(); entity.HasOne(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict); });
        modelBuilder.Entity<ContactMessage>(entity => { entity.Property(message => message.FullName).HasMaxLength(150).IsRequired(); entity.Property(message => message.Email).HasMaxLength(254).IsRequired(); entity.Property(message => message.Phone).HasMaxLength(50).IsRequired(); entity.Property(message => message.Message).HasMaxLength(3000).IsRequired(); entity.Property(message => message.CreatedAtUtc).HasConversion(utcDateTimeConverter); });
        modelBuilder.Entity<ContactMessage>().HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<FaqEntry>(entity => { entity.Property(item => item.Question).HasMaxLength(300).IsRequired(); entity.Property(item => item.Answer).HasMaxLength(3000).IsRequired(); });
        modelBuilder.Entity<FaqEntry>().HasOne(x => x.StudioAbout).WithMany().HasForeignKey(x => x.StudioAboutId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<StudioAbout>(entity => { entity.Property(item => item.Title).HasMaxLength(200).IsRequired(); entity.Property(item => item.Content).HasMaxLength(5000).IsRequired(); entity.Property(item => item.ImageUrl).HasMaxLength(2048); });
        modelBuilder.Entity<Payment>(entity => { entity.Property(item => item.Status).HasConversion<string>(); entity.Property(item => item.Amount).HasPrecision(18, 2); entity.Property(item => item.Currency).HasMaxLength(3).IsRequired(); entity.Property(item => item.StripeCheckoutSessionId).HasMaxLength(255).IsRequired(); entity.Property(item => item.StripePaymentIntentId).HasMaxLength(255); entity.Property(item => item.CreatedAtUtc).HasConversion(utcDateTimeConverter); entity.Property(item => item.PaidAtUtc).HasConversion(utcDateTimeConverter); entity.HasIndex(item => item.ReservationId).IsUnique(); entity.HasIndex(item => item.StripeCheckoutSessionId).IsUnique(); entity.HasOne(item => item.Reservation).WithMany().HasForeignKey(item => item.ReservationId).OnDelete(DeleteBehavior.Restrict); });
        modelBuilder.Entity<Payment>(entity => { entity.Property(x => x.StripeCheckoutSessionId).IsRequired(false); entity.HasIndex(x => x.StripeCheckoutSessionId).IsUnique().HasFilter("[StripeCheckoutSessionId] IS NOT NULL"); entity.Property(x => x.RefundedAmount).HasPrecision(18, 2); entity.Property(x => x.StripeRefundId).HasMaxLength(255); entity.Property(x => x.ReceiptUrl).HasMaxLength(2048); });
        modelBuilder.Entity<StudioAbout>().HasOne(x => x.City).WithMany().HasForeignKey(x => x.CityId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<UserActivity>(entity =>
        {
            entity.Property(activity => activity.Type).HasConversion<string>();
            entity.HasIndex(activity => new { activity.UserId, activity.Type, activity.CreatedAtUtc });
            entity.HasOne(activity => activity.User).WithMany().HasForeignKey(activity => activity.UserId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<BeautyService>().WithMany().HasForeignKey(activity => activity.ServiceId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne<ServiceCategory>().WithMany().HasForeignKey(activity => activity.CategoryId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne<BlogPost>().WithMany().HasForeignKey(activity => activity.BlogPostId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne<GalleryItem>().WithMany().HasForeignKey(activity => activity.GalleryItemId).OnDelete(DeleteBehavior.SetNull);
        });
    }
}
