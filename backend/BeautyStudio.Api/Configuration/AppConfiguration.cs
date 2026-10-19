namespace BeautyStudio.Api.Configuration;

public sealed class AppConfiguration
{
    public string ConnectionString { get; } = Required("CONNECTION_STRING");
    public string JwtKey { get; } = Required("JWT_KEY");
    public string JwtIssuer { get; } = Required("JWT_ISSUER");
    public string JwtAudience { get; } = Required("JWT_AUDIENCE");
    public string[] FrontendOrigins { get; } = Required("FRONTEND_ORIGINS").Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    public string RabbitHost { get; } = Environment.GetEnvironmentVariable("RABBITMQ_HOST") ?? "localhost";
    public int RabbitPort { get; } = int.TryParse(Environment.GetEnvironmentVariable("RABBITMQ_PORT"), out var port) ? port : 5672;
    public string RabbitUser { get; } = Environment.GetEnvironmentVariable("RABBITMQ_USER") ?? "beautystudio";
    public string RabbitPassword { get; } = Environment.GetEnvironmentVariable("RABBITMQ_PASSWORD") ?? "";
    public string RabbitQueue { get; } = Environment.GetEnvironmentVariable("RABBITMQ_QUEUE") ?? "beautystudio.notifications";
    public string? StripeSecretKey { get; } = Environment.GetEnvironmentVariable("STRIPE_SECRET_KEY");
    public string? StripeWebhookSecret { get; } = Environment.GetEnvironmentVariable("STRIPE_WEBHOOK_SECRET");
    public string PaymentReturnBaseUrl { get; } = Environment.GetEnvironmentVariable("PAYMENT_RETURN_BASE_URL") ?? "http://localhost:5000";
    public string PaymentMobileReturnBaseUrl { get; } = Environment.GetEnvironmentVariable("PAYMENT_MOBILE_RETURN_BASE_URL") ?? "http://10.0.2.2:5000";
    public bool SeedDemoData { get; } = bool.TryParse(Environment.GetEnvironmentVariable("SEED_DEMO_DATA"), out var seed) && seed;
    public string PaymentAppScheme { get; } = Environment.GetEnvironmentVariable("PAYMENT_APP_SCHEME") ?? "beautystudio";
    public string Currency { get; } = Environment.GetEnvironmentVariable("PAYMENT_CURRENCY") ?? "bam";
    public string TimeZone { get; } = Environment.GetEnvironmentVariable("STUDIO_TIME_ZONE") ?? "Europe/Zagreb";
    private static string Required(string key) => Environment.GetEnvironmentVariable(key) ?? throw new InvalidOperationException($"Konfiguracija {key} nije postavljena.");
}
