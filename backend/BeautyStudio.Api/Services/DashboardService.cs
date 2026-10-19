using BeautyStudio.Api.Contracts.Dashboard;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class DashboardService(BeautyStudioDbContext db)
{
    public async Task<DashboardResponse> GetAsync(CancellationToken cancellationToken)
    {
        var totalReservations = await db.Reservations.CountAsync(cancellationToken);
        var activeReservations = await db.Reservations.CountAsync(reservation => reservation.Status == ReservationStatus.Pending || reservation.Status == ReservationStatus.Confirmed, cancellationToken);
        var activeClients = await db.Users.CountAsync(user => user.Role == UserRole.Client && user.IsActive, cancellationToken);
        var completedRevenue = await db.PaymentTransactions.SumAsync(x => (decimal?)(x.Kind == "Refund" ? -x.Amount : x.Amount), cancellationToken) ?? 0m;
        var services = await db.Services.AsNoTracking().OrderBy(item => item.Name).Select(item => new { item.Id, item.Name }).ToListAsync(cancellationToken);
        var reservationCounts = await db.Reservations.AsNoTracking().GroupBy(item => item.ServiceId).Select(group => new { ServiceId = group.Key, Total = group.Count(), Completed = group.Count(item => item.Status == ReservationStatus.Completed) }).ToListAsync(cancellationToken);
        var counts = reservationCounts.ToDictionary(item => item.ServiceId);
        var popularServices = services.Select(service => new PopularServiceResponse(service.Id, service.Name, counts.GetValueOrDefault(service.Id)?.Total ?? 0, counts.GetValueOrDefault(service.Id)?.Completed ?? 0)).OrderByDescending(item => item.ReservationCount).ThenByDescending(item => item.CompletedCount).ThenBy(item => item.Name).Take(5).ToList();
        var recentReservations = await db.Reservations.AsNoTracking()
            .OrderByDescending(reservation => reservation.CreatedAtUtc)
            .Take(8)
            .Select(reservation => new DashboardReservationResponse(reservation.Id, reservation.User.FirstName + " " + reservation.User.LastName, reservation.Service.Name, reservation.StartAtUtc, reservation.Status.ToString()))
            .ToListAsync(cancellationToken);

        return new DashboardResponse(totalReservations, activeReservations, activeClients, completedRevenue, popularServices.FirstOrDefault()?.Name, recentReservations, popularServices);
    }
}
