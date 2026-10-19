using BeautyStudio.Api.Contracts.Content;
using BeautyStudio.Api.Contracts.Profile;
using BeautyStudio.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BeautyStudio.Api.Controllers;

[ApiController]
[Route("api/profile")]
[Authorize]
public sealed class ProfileController(ProfileService service) : ControllerBase
{
    [HttpGet] public Task<ProfileResponse> Get(CancellationToken cancellationToken) => service.GetAsync(cancellationToken);
    [HttpPost("image")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public Task<ImageUploadResponse> UploadImage([FromForm] IFormFile file, [FromServices] ContentImageService imageService, CancellationToken cancellationToken) => imageService.UploadProfileAsync(file, cancellationToken);
    [HttpGet("images/{fileName}")]
    public PhysicalFileResult Image(string fileName, [FromServices] ContentImageService imageService) { var image = imageService.ProfileImage(fileName); return PhysicalFile(image.Path, image.Mime); }
    [HttpPut] public Task<ProfileResponse> Update(UpdateProfileRequest request, CancellationToken cancellationToken) => service.UpdateAsync(request, cancellationToken);
}
