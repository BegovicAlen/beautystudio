using BeautyStudio.Api.Contracts.Content;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Services;

public sealed class ContentManagementService(BeautyStudioDbContext db)
{
    public async Task<GalleryItemResponse> CreateGalleryAsync(UpsertGalleryItemRequest request, CancellationToken cancellationToken)
    {
        Validate(request.Title, request.ImageUrl);
        var description = GalleryDescription(request.Description);
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        var item = new GalleryItem { Id = Guid.NewGuid(), Title = request.Title.Trim(), Description = description, ImageUrl = request.ImageUrl.Trim(), CategoryId = category.Id, IsActive = request.IsActive };
        db.GalleryItems.Add(item); await db.SaveChangesAsync(cancellationToken); return new GalleryItemResponse(item.Id, item.Title, item.ImageUrl, category.Name, item.CreatedAtUtc, item.CategoryId, item.Description);
    }

    public async Task<GalleryItemResponse> UpdateGalleryAsync(Guid id, UpsertGalleryItemRequest request, CancellationToken cancellationToken)
    {
        Validate(request.Title, request.ImageUrl);
        var description = GalleryDescription(request.Description);
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        var item = await db.GalleryItems.SingleOrDefaultAsync(item => item.Id == id, cancellationToken) ?? throw new NotFoundException("Stavka galerije nije pronađena.");
        item.Title = request.Title.Trim(); item.Description = description; item.ImageUrl = request.ImageUrl.Trim(); item.CategoryId = category.Id; item.IsActive = request.IsActive;
        await db.SaveChangesAsync(cancellationToken); return new GalleryItemResponse(item.Id, item.Title, item.ImageUrl, category.Name, item.CreatedAtUtc, item.CategoryId, item.Description);
    }

    public async Task<BlogPostResponse> CreateBlogPostAsync(UpsertBlogPostRequest request, CancellationToken cancellationToken)
    {
        Validate(request.Title, request.Content);
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        var post = new BlogPost { Id = Guid.NewGuid(), Title = request.Title.Trim(), Content = request.Content.Trim(), CategoryId = category.Id, ImageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim(), IsPublished = request.IsPublished, PublishedAtUtc = DateTime.UtcNow };
        db.BlogPosts.Add(post); await db.SaveChangesAsync(cancellationToken); return new BlogPostResponse(post.Id, post.Title, post.Content, post.ImageUrl, post.PublishedAtUtc, post.CategoryId, category.Name);
    }

    public async Task<BlogPostResponse> UpdateBlogPostAsync(Guid id, UpsertBlogPostRequest request, CancellationToken cancellationToken)
    {
        Validate(request.Title, request.Content);
        var post = await db.BlogPosts.SingleOrDefaultAsync(post => post.Id == id, cancellationToken) ?? throw new NotFoundException("Blog objava nije pronađena.");
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        post.Title = request.Title.Trim(); post.Content = request.Content.Trim(); post.CategoryId = category.Id; post.ImageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim(); post.IsPublished = request.IsPublished;
        await db.SaveChangesAsync(cancellationToken); return new BlogPostResponse(post.Id, post.Title, post.Content, post.ImageUrl, post.PublishedAtUtc, post.CategoryId, category.Name);
    }

    private static string GalleryDescription(string? value)
    {
        var description = value?.Trim() ?? string.Empty;
        if (description.Length > 3000) throw new BusinessException("Opis slike može sadržavati najviše 3000 znakova.");
        return description;
    }

    private static void Validate(string title, string value, string? category = null)
    {
        if (string.IsNullOrWhiteSpace(title) || string.IsNullOrWhiteSpace(value) || category is not null && string.IsNullOrWhiteSpace(category)) throw new BusinessException("Naslov i obavezna polja sadržaja moraju biti popunjeni.");
        InputValidation.Text(title, "Naslov", 150);
        InputValidation.Text(value, "Sadržaj", 10000);
    }

    private async Task<ServiceCategory> CategoryAsync(int id, CancellationToken ct) => await db.ServiceCategories.SingleOrDefaultAsync(x => x.Id == id && x.IsActive, ct) ?? throw new BusinessException("Odaberite aktivnu kategoriju iz liste.");
}
