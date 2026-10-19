using System.Net;
using BeautyStudio.Api.Configuration;
using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Contracts.Payments;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;
[ApiController, Route("api/payments"), Authorize]
public sealed class PaymentsController(PaymentService payments, ListQueryService queries, ReportService reports, AppConfiguration config) : ControllerBase
{
    [HttpPost("reservation/{reservationId:guid}/checkout")] public Task<CheckoutResponse> Checkout(Guid reservationId, [FromBody(EmptyBodyBehavior = Microsoft.AspNetCore.Mvc.ModelBinding.EmptyBodyBehavior.Allow)] CheckoutRequest? request, CancellationToken ct) => payments.CheckoutAsync(reservationId, ct, request?.Mobile ?? false);
    [HttpPost("reservation/{reservationId:guid}/verify")] public Task<PaymentResponse> Verify(Guid reservationId, CancellationToken ct) => payments.VerifyAsync(reservationId, ct);
    [HttpGet("mine")] public Task<PagedResponse<PaymentResponse>> Mine([FromQuery] ListQuery q, CancellationToken ct) => queries.PaymentsAsync(q, true, ct);
    [Authorize(Roles = "Admin,Owner"), HttpGet] public Task<PagedResponse<PaymentResponse>> All([FromQuery] ListQuery q, CancellationToken ct) => queries.PaymentsAsync(q, false, ct);
    [HttpGet("reservation/{reservationId:guid}/receipt")] public async Task<FileContentResult> Receipt(Guid reservationId, CancellationToken ct) => File(await reports.PaymentReceiptAsync(reservationId, User, ct), "application/pdf", "potvrda-placanja.pdf");
    [AllowAnonymous, HttpGet("return")]
    public ContentResult Return([FromQuery] Guid reservationId, [FromQuery] string? result)
    {
        var link = WebUtility.HtmlEncode(config.PaymentAppScheme + "://payment-return?reservationId=" + reservationId);
        return Content("<!doctype html><html lang='bs'><meta name='viewport' content='width=device-width,initial-scale=1'><title>BeautyStudio</title><body style='font-family:sans-serif;padding:40px;text-align:center'><h1>BeautyStudio</h1><p>Vratite se u aplikaciju radi provjere statusa plaćanja.</p><a id='return' href='" + link + "'>Vrati se u BeautyStudio</a><script>window.location.href=document.getElementById('return').href;</script></body></html>", "text/html; charset=utf-8");
    }
}
