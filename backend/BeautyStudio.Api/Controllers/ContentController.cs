using BeautyStudio.Api.Contracts.Common;
using BeautyStudio.Api.Contracts.Content;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api")]
public sealed class ContentController(ListQueryService queries) : ControllerBase
{
    [AllowAnonymous]
    [HttpGet("gallery")]
    public Task<PagedResponse<ManagedGalleryItemResponse>> GetGallery([FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.GalleryAsync(q, false, cancellationToken);

    [AllowAnonymous]
    [HttpGet("blog-posts")]
    public Task<PagedResponse<ManagedBlogPostResponse>> GetBlogPosts([FromQuery] ListQuery q, CancellationToken cancellationToken) => queries.BlogsAsync(q, false, cancellationToken);
    [AllowAnonymous, HttpGet("blog-posts/{id:guid}")]
    public Task<ManagedBlogPostResponse> Blog(Guid id, CancellationToken ct) => queries.BlogAsync(id, false, ct);
}
