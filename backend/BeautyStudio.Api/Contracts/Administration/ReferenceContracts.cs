namespace BeautyStudio.Api.Contracts.Administration;
public sealed record ReferenceResponse(int Id, string Name, bool IsActive, string? Code = null);
public sealed record UpsertReferenceRequest(string Name, bool IsActive, string? Code = null);
