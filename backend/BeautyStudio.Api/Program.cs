using System.Text;
using System.Text.Json.Serialization;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Services;
using DotNetEnv;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.FileProviders;
using QuestPDF.Infrastructure;
using BeautyStudio.Api.Configuration;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

var environmentFile = Path.Combine(Directory.GetCurrentDirectory(), ".env");
if (!File.Exists(environmentFile)) environmentFile = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", ".env"));
if (File.Exists(environmentFile)) Env.Load(environmentFile);
QuestPDF.Settings.License = LicenseType.Community;
var builder = WebApplication.CreateBuilder(args);
var config = new AppConfiguration();
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.Warning);
builder.Services.AddSingleton(config);

builder.Services.AddDbContext<BeautyStudioDbContext>(options => options.UseSqlServer(config.ConnectionString));
builder.Services.AddMemoryCache();
builder.Services.AddControllers().AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ReservationService>();
builder.Services.AddScoped<IReservationService>(provider => provider.GetRequiredService<ReservationService>());
builder.Services.AddScoped<ListQueryService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ContentManagementService>();
builder.Services.AddScoped<ContentImageService>();
builder.Services.AddScoped<DashboardService>();
builder.Services.AddScoped<AdministrationService>();
builder.Services.AddScoped<ReportService>();
builder.Services.AddScoped<ProfileService>();
builder.Services.AddScoped<ContactService>();
builder.Services.AddScoped<InformationService>();
builder.Services.AddScoped<PaymentService>();
builder.Services.AddScoped<RecommendationService>();
builder.Services.AddScoped<ActivityService>();
builder.Services.AddScoped<NotificationService>();
builder.Services.AddScoped<ReviewService>();
builder.Services.AddScoped<NotificationComposer>();
builder.Services.AddScoped<ReferenceService>();
builder.Services.AddHostedService<NotificationPublisherWorker>();
builder.Services.AddHostedService<ExpiredReservationStatusWorker>();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddCors(options => options.AddPolicy("BeautyStudioClients", policy => policy.WithOrigins(config.FrontendOrigins).AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddRateLimiter(options => {
    options.RejectionStatusCode = 429;
    options.AddPolicy("contact", context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    options.AddPolicy("auth", context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options => {
    options.TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuer = true, ValidIssuer = config.JwtIssuer, ValidateAudience = true, ValidAudience = config.JwtAudience,
    ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config.JwtKey)), ValidateLifetime = true, ClockSkew = TimeSpan.Zero,
    };
    options.Events = new JwtBearerEvents { OnTokenValidated = async context => {
        var principal = context.Principal!;
        var db = context.HttpContext.RequestServices.GetRequiredService<BeautyStudioDbContext>();
        if (!Guid.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) { context.Fail("Invalid account."); return; }
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, context.HttpContext.RequestAborted);
        var version = int.TryParse(principal.FindFirstValue("token_version"), out var v) ? v : -1;
        var jti = principal.FindFirstValue("jti");
        if (user == null || !user.IsActive || user.TokenVersion != version || user.Role.ToString() != principal.FindFirstValue(ClaimTypes.Role) || jti == null || await db.RevokedTokens.AnyAsync(x => x.Id == jti, context.HttpContext.RequestAborted)) context.Fail("Session expired or revoked.");
    } };
});
builder.Services.AddAuthorization(options =>
    options.FallbackPolicy = new Microsoft.AspNetCore.Authorization.AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser().Build());

var app = builder.Build();
var webRoot = app.Environment.WebRootPath ?? Path.Combine(app.Environment.ContentRootPath, "wwwroot");
Directory.CreateDirectory(Path.Combine(webRoot, "uploads"));
app.UseExceptionHandler();
app.UseCors("BeautyStudioClients");
app.UseStaticFiles(new StaticFileOptions { FileProvider = new PhysicalFileProvider(webRoot) });
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { status = "healthy" })).AllowAnonymous();
using (var scope = app.Services.CreateScope())
    await DatabaseSeeder.SeedAsync(scope.ServiceProvider.GetRequiredService<BeautyStudioDbContext>(), CancellationToken.None, config.SeedDemoData);
app.Run();

public partial class Program;
