using System.Text.Json;
using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Services;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace BeautyStudio.Worker;

public sealed class NotificationConsumer(IServiceScopeFactory scopes, AppConfiguration config, ILogger<NotificationConsumer> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var factory = new ConnectionFactory { HostName = config.RabbitHost, Port = config.RabbitPort, UserName = config.RabbitUser, Password = config.RabbitPassword, DispatchConsumersAsync = true, AutomaticRecoveryEnabled = true };
                using var connection = factory.CreateConnection();
                using var channel = connection.CreateModel();
                channel.QueueDeclare(config.RabbitQueue, true, false, false);
                channel.BasicQos(0, 1, false);
                var consumer = new AsyncEventingBasicConsumer(channel);
                consumer.Received += async (_, delivery) =>
                {
                    for (var attempt = 0; ; attempt++)
                    {
                        try
                        {
                            var item = JsonSerializer.Deserialize<NotificationEnvelope>(delivery.Body.Span) ?? throw new InvalidDataException("Notification payload is empty.");
                            using var scope = scopes.CreateScope();
                            var db = scope.ServiceProvider.GetRequiredService<BeautyStudioDbContext>();
                            if (!await db.Notifications.AnyAsync(x => x.Id == item.Id, stoppingToken))
                            {
                                db.Notifications.Add(new Notification { Id = item.Id, UserId = item.UserId, NotificationTypeId = item.NotificationTypeId, Title = item.Title, Message = item.Message, CreatedAtUtc = item.CreatedAtUtc });
                                await db.SaveChangesAsync(stoppingToken);
                            }
                            channel.BasicAck(delivery.DeliveryTag, false);
                            break;
                        }
                        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
                        catch (Exception e)
                        {
                            logger.LogError(e, "Notification {MessageId} processing failed, attempt {Attempt}.", delivery.BasicProperties.MessageId, attempt + 1);
                            if (attempt >= 4)
                            {
                                channel.QueueDeclare(config.RabbitQueue + ".dead", true, false, false);
                                var properties = channel.CreateBasicProperties();
                                properties.Persistent = true;
                                properties.MessageId = delivery.BasicProperties.MessageId;
                                channel.BasicPublish("", config.RabbitQueue + ".dead", properties, delivery.Body);
                                channel.BasicAck(delivery.DeliveryTag, false);
                                break;
                            }
                            await Task.Delay(TimeSpan.FromSeconds(Math.Min(30, Math.Pow(2, Math.Min(attempt, 5)))), stoppingToken);
                        }
                    }
                };
                channel.BasicConsume(config.RabbitQueue, false, consumer);
                while (connection.IsOpen && !stoppingToken.IsCancellationRequested) await Task.Delay(1000, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception e) { logger.LogError(e, "Notification worker connection failed; retrying."); await Task.Delay(5000, stoppingToken); }
        }
    }
}
