using System.Data;
using BeautyStudio.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace BeautyStudio.Api.Services;

public static class BookingLock
{
    public static async Task<IDbContextTransaction> BeginAsync(BeautyStudioDbContext db, CancellationToken ct)
    {
        var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            await db.Database.ExecuteSqlRawAsync("DECLARE @result int; EXEC @result = sys.sp_getapplock @Resource = 'BeautyStudio.Booking', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000; IF @result < 0 THROW 51000, 'Booking lock unavailable', 1;", ct);
            return transaction;
        }
        catch { await transaction.DisposeAsync(); throw; }
    }
}
