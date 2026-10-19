namespace BeautyStudio.Api.Domain;
public sealed class StudioAbout
{
    public int Id { get; set; }
    public required string Title { get; set; }
    public required string Content { get; set; }
    public string? ImageUrl { get; set; }
    public string Address { get; set; } = "";
    public string Phone { get; set; } = "";
    public string Email { get; set; } = "";
    public int FoundedYear { get; set; } = 2020;
    public int OpeningHour { get; set; } = 9;
    public int ClosingHour { get; set; } = 20;
    public int DepositPercent { get; set; } = 100;
    public int? CityId { get; set; }
    public City? City { get; set; }
}
