namespace BeautyStudio.Api.Contracts.Auth;
public sealed record RegisterRequest(string FirstName, string LastName, string Username, string Email, string Password);
