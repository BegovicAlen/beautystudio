namespace BeautyStudio.Api.Domain;
public sealed class FaqEntry { public Guid Id { get; set; } public required string Question { get; set; } public required string Answer { get; set; } public bool IsActive { get; set; } = true; public int SortOrder { get; set; } public int? StudioAboutId { get; set; } public StudioAbout? StudioAbout { get; set; } }
