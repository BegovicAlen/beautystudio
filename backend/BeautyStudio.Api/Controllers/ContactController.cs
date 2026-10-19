using BeautyStudio.Api.Contracts.Contact;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
namespace BeautyStudio.Api.Controllers;
[ApiController, Route("api/contact")]
public sealed class ContactController(ContactService service, ListQueryService queries) : ControllerBase
{
    [AllowAnonymous, HttpPost, EnableRateLimiting("contact")] public Task<ContactMessageResponse> Create(CreateContactMessageRequest request, CancellationToken cancellationToken) => service.CreateAsync(request, cancellationToken);
    [Authorize(Roles = "Admin,Owner"), HttpGet] public Task<BeautyStudio.Api.Contracts.Common.PagedResponse<ContactMessageResponse>> Get([FromQuery] BeautyStudio.Api.Contracts.Common.ListQuery q, CancellationToken cancellationToken) => queries.ContactsAsync(q, cancellationToken);
}
