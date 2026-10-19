using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public static class StatusDefinitions
{
    public static async Task<ReservationStatusDefinition> ResolveAsync(BeautyStudioDbContext db, ReservationStatus code, int? id, CancellationToken ct)
    {
        var query = db.ReservationStatuses.Where(x => x.Code == code && x.IsActive);
        if (id.HasValue) query = query.Where(x => x.Id == id.Value);
        return await query.OrderBy(x => x.Id).FirstOrDefaultAsync(ct) ?? throw new BusinessException("Odabrani naziv statusa nije aktivan ili ne odgovara poslovnom stanju.");
    }
}
