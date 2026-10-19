using BeautyStudio.Api.Contracts.Content;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/admin/content")]
[Authorize(Roles = "Admin,Owner")]
public sealed class ContentManagementController(ContentManagementService service, ListQueryService queries) : ControllerBase
{
    [HttpPost("uploads/images")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public Task<ImageUploadResponse> UploadImage([FromForm] IFormFile file, [FromServices] ContentImageService imageService, CancellationToken cancellationToken) => imageService.UploadAsync(file, cancellationToken);

    [HttpGet("gallery")] public Task<BeautyStudio.Api.Contracts.Common.PagedResponse<ManagedGalleryItemResponse>> Gallery([FromQuery] BeautyStudio.Api.Contracts.Common.ListQuery q, CancellationToken cancellationToken) => queries.GalleryAsync(q, true, cancellationToken);
    [HttpPost("gallery")] public Task<GalleryItemResponse> CreateGallery(UpsertGalleryItemRequest request, CancellationToken cancellationToken) => service.CreateGalleryAsync(request, cancellationToken);
    [HttpPut("gallery/{id:guid}")] public Task<GalleryItemResponse> UpdateGallery(Guid id, UpsertGalleryItemRequest request, CancellationToken cancellationToken) => service.UpdateGalleryAsync(id, request, cancellationToken);
    [HttpGet("blog-posts")] public Task<BeautyStudio.Api.Contracts.Common.PagedResponse<ManagedBlogPostResponse>> BlogPosts([FromQuery] BeautyStudio.Api.Contracts.Common.ListQuery q, CancellationToken cancellationToken) => queries.BlogsAsync(q, true, cancellationToken);
    [HttpGet("blog-posts/{id:guid}")] public Task<ManagedBlogPostResponse> Blog(Guid id, CancellationToken ct) => queries.BlogAsync(id, true, ct);
    [HttpPost("blog-posts")] public Task<BlogPostResponse> CreateBlogPost(UpsertBlogPostRequest request, CancellationToken cancellationToken) => service.CreateBlogPostAsync(request, cancellationToken);
    [HttpPut("blog-posts/{id:guid}")] public Task<BlogPostResponse> UpdateBlogPost(Guid id, UpsertBlogPostRequest request, CancellationToken cancellationToken) => service.UpdateBlogPostAsync(id, request, cancellationToken);
}
