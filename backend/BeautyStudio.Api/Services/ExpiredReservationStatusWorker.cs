namespace BeautyStudio.Api.Services;

public sealed class ExpiredReservationStatusWorker(IServiceScopeFactory scopeFactory, ILogger<ExpiredReservationStatusWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await ProcessAsync(stoppingToken);
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        while (await timer.WaitForNextTickAsync(stoppingToken)) await ProcessAsync(stoppingToken);
    }

    private async Task ProcessAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var reservationService = scope.ServiceProvider.GetRequiredService<IReservationService>();
            var changedCount = await reservationService.ProcessExpiredReservationsAsync(cancellationToken);
            if (changedCount > 0) logger.LogInformation("Automatically updated {ReservationCount} expired reservations.", changedCount);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Unable to process expired reservations.");
        }
    }
}
