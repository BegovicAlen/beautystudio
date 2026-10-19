using BeautyStudio.Api.Contracts.Content;
using BeautyStudio.Api.Exceptions;
using Microsoft.AspNetCore.Http;
using System.Security.Claims;

namespace BeautyStudio.Api.Services;

public sealed class ContentImageService(IWebHostEnvironment environment, IHttpContextAccessor http)
{
    private const long MaximumFileSize = 5 * 1024 * 1024;

    public Task<ImageUploadResponse> UploadAsync(IFormFile file, CancellationToken cancellationToken) => SaveAsync(file, false, cancellationToken);
    public Task<ImageUploadResponse> UploadProfileAsync(IFormFile file, CancellationToken cancellationToken) => SaveAsync(file, true, cancellationToken);

    public (string Path, string Mime) ProfileImage(string fileName)
    {
        var owner = Guid.Parse(http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        if (Path.GetFileName(fileName) != fileName || !fileName.StartsWith(owner.ToString("N") + "-")) throw new NotFoundException("Slika nije pronađena.");
        var path = Path.Combine(environment.ContentRootPath, "private-uploads", fileName);
        if (!File.Exists(path)) throw new NotFoundException("Slika nije pronađena.");
        return (path, Path.GetExtension(fileName) switch { ".png" => "image/png", ".webp" => "image/webp", _ => "image/jpeg" });
    }

    private async Task<ImageUploadResponse> SaveAsync(IFormFile file, bool profile, CancellationToken cancellationToken)
    {
        if (file.Length == 0) throw new BusinessException("Odaberite sliku za upload.");
        if (file.Length > MaximumFileSize) throw new BusinessException("Slika može imati najviše 5 MB.");

        var extension = await DetectImageExtensionAsync(file, cancellationToken);
        if (extension is null) throw new BusinessException("Dozvoljene su samo stvarne JPG, PNG ili WEBP slike.");

        var declaredType = file.ContentType.ToLowerInvariant();
        if (declaredType is not "image/jpeg" and not "image/png" and not "image/webp")
            throw new BusinessException("Odaberite JPG, PNG ili WEBP sliku.");
        if ((extension == ".jpg" && declaredType != "image/jpeg") || (extension == ".png" && declaredType != "image/png") || (extension == ".webp" && declaredType != "image/webp"))
            throw new BusinessException("Tip slike ne odgovara stvarnom sadržaju datoteke.");

        var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
        var directory = profile ? Path.Combine(environment.ContentRootPath, "private-uploads") : Path.Combine(webRoot, "uploads");
        Directory.CreateDirectory(directory);

        var ownerPrefix = profile ? Guid.Parse(http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!).ToString("N") + "-" : "";
        var fileName = $"{ownerPrefix}{Guid.NewGuid():N}{extension}";
        var destination = Path.Combine(directory, fileName);
        await using var output = File.Create(destination);
        await file.CopyToAsync(output, cancellationToken);
        return new ImageUploadResponse(profile ? $"/api/profile/images/{fileName}" : $"/uploads/{fileName}");
    }

    private static async Task<string?> DetectImageExtensionAsync(IFormFile file, CancellationToken cancellationToken)
    {
        var header = new byte[12];
        await using var input = file.OpenReadStream();
        var count = await input.ReadAsync(header.AsMemory(0, header.Length), cancellationToken);
        if (count >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) return ".jpg";
        if (count >= 8 && header[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })) return ".png";
        if (count >= 12 && header.AsSpan(0, 4).SequenceEqual("RIFF"u8) && header.AsSpan(8, 4).SequenceEqual("WEBP"u8)) return ".webp";
        return null;
    }
}
