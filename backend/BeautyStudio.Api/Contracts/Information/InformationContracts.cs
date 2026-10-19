namespace BeautyStudio.Api.Contracts.Information;
public sealed record FaqResponse(Guid Id,string Question,string Answer,bool IsActive,int SortOrder);
public sealed record UpsertFaqRequest(string Question,string Answer,bool IsActive,int SortOrder);
public sealed record AboutResponse(string Title,string Content,string? ImageUrl, string Address = "", string Phone = "", string Email = "", int FoundedYear = 2020, int OpeningHour = 9, int ClosingHour = 20, int DepositPercent = 100, int? CityId = null, string? CityName = null, int ClientCount = 0, double AverageRating = 0);
public sealed record UpsertAboutRequest(string Title,string Content,string? ImageUrl, string Address = "", string Phone = "", string Email = "", int FoundedYear = 2020, int OpeningHour = 9, int ClosingHour = 20, int DepositPercent = 100, int? CityId = null);
