using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Data;
using BeautyStudio.Worker;
using DotNetEnv;
using Microsoft.EntityFrameworkCore;

var file = Path.Combine(Directory.GetCurrentDirectory(), ".env");
if (!File.Exists(file)) file = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", ".env"));
if (File.Exists(file)) Env.Load(file);
var builder = Host.CreateApplicationBuilder(args);
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.Warning);
var config = new AppConfiguration();
builder.Services.AddSingleton(config);
builder.Services.AddDbContext<BeautyStudioDbContext>(options => options.UseSqlServer(config.ConnectionString));
builder.Services.AddHostedService<NotificationConsumer>();
await builder.Build().RunAsync();
