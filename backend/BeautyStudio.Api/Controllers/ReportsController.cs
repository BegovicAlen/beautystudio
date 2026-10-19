using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/reports")]
[Authorize(Roles = "Admin,Owner")]
public sealed class ReportsController(ReportService service) : ControllerBase
{
    [HttpGet("reservations")]
    public async Task<FileContentResult> Reservations([FromQuery] DateOnly from, [FromQuery] DateOnly to, CancellationToken cancellationToken) => File(await service.ReservationReportAsync(from, to, cancellationToken), "application/pdf", $"beautystudio-rezervacije-{from:yyyyMMdd}-{to:yyyyMMdd}.pdf");
    [HttpGet("popular-services")]
    public async Task<FileContentResult> PopularServices([FromQuery] DateOnly from, [FromQuery] DateOnly to, CancellationToken cancellationToken) => File(await service.PopularServicesReportAsync(from, to, cancellationToken), "application/pdf", $"beautystudio-usluge-{from:yyyyMMdd}-{to:yyyyMMdd}.pdf");
    [HttpGet("payments")]
    public async Task<FileContentResult> Payments([FromQuery] DateOnly from, [FromQuery] DateOnly to, CancellationToken cancellationToken) => File(await service.PaymentReportAsync(from, to, cancellationToken), "application/pdf", $"beautystudio-placanja-{from:yyyyMMdd}-{to:yyyyMMdd}.pdf");
}
