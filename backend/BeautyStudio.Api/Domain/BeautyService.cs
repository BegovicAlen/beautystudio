namespace BeautyStudio.Api.Domain;

public sealed class BeautyService
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public required string Description { get; set; }
    public decimal Price { get; set; }
    public int DurationMinutes { get; set; }
    public bool IsActive { get; set; } = true;
    public int CategoryId { get; set; }
    public ServiceCategory Category { get; set; } = null!;
}
