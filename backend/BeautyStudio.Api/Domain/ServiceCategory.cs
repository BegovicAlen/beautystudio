namespace BeautyStudio.Api.Domain;

public sealed class ServiceCategory
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public bool IsActive { get; set; } = true;
    public ICollection<BeautyService> Services { get; set; } = new List<BeautyService>();
}
