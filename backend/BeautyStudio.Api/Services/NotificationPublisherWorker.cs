using System.Text.Json;
using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Data;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;

namespace BeautyStudio.Api.Services;

public sealed record NotificationEnvelope(Guid Id, Guid UserId, int NotificationTypeId, string Title, string Message, DateTime CreatedAtUtc);

public sealed class NotificationPublisherWorker(IServiceScopeFactory scopeFactory, AppConfiguration config, ILogger<NotificationPublisherWorker> logger) : BackgroundService
{
    private IConnection? connection;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(2));
        do
        {
            try
            {
                if (connection is not { IsOpen: true })
                {
                    connection?.Dispose();
                    connection = new ConnectionFactory { HostName = config.RabbitHost, Port = config.RabbitPort, UserName = config.RabbitUser, Password = config.RabbitPassword, AutomaticRecoveryEnabled = true }.CreateConnection();
                }
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<BeautyStudioDbContext>();
                var pending = await db.NotificationOutbox.Where(x => x.PublishedAtUtc == null).OrderBy(x => x.CreatedAtUtc).Take(50).ToListAsync(stoppingToken);
                if (pending.Count == 0) continue;
                using var channel = connection.CreateModel();
                channel.QueueDeclare(config.RabbitQueue, durable: true, exclusive: false, autoDelete: false);
                channel.ConfirmSelect();
                foreach (var item in pending)
                {
                    var properties = channel.CreateBasicProperties();
                    properties.Persistent = true;
                    properties.MessageId = item.Id.ToString();
                    var payload = new NotificationEnvelope(item.Id, item.UserId, item.NotificationTypeId, item.Title, item.Message, item.CreatedAtUtc);
                    channel.BasicPublish("", config.RabbitQueue, properties, JsonSerializer.SerializeToUtf8Bytes(payload));
                    channel.WaitForConfirmsOrDie(TimeSpan.FromSeconds(5));
                    item.PublishedAtUtc = DateTime.UtcNow;
                }
                await db.SaveChangesAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception e) { logger.LogError(e, "Notification outbox publication failed; saved events will be retried."); }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    public override void Dispose() { connection?.Dispose(); base.Dispose(); }
}
