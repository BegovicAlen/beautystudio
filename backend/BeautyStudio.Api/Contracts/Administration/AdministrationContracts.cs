namespace BeautyStudio.Api.Contracts.Administration;

public sealed record ManagedServiceResponse(int Id, string Name, string Description, decimal Price, int DurationMinutes, int CategoryId, string CategoryName, bool IsActive);
public sealed record ManagedCategoryResponse(int Id, string Name, bool IsActive, int ServiceCount);
public sealed record UpsertServiceRequest(string Name, string Description, decimal Price, int DurationMinutes, int CategoryId, bool IsActive);
public sealed record UpsertCategoryRequest(string Name, bool IsActive);
public sealed record ManagedUserResponse(Guid Id, string FirstName, string LastName, string Username, string Email, string Role, bool IsActive);
public sealed record CreateUserRequest(string FirstName, string LastName, string Username, string Email, string Password, string Role, bool IsActive);
public sealed record UpdateUserRequest(string FirstName, string LastName, string Username, string Email, string? Password, string Role, bool IsActive);
