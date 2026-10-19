namespace BeautyStudio.Api.Contracts.Contact;
public sealed record CreateContactMessageRequest(string FullName, string Email, string Phone, string Message);
public sealed record ContactMessageResponse(Guid Id, string FullName, string Email, string Phone, string Message, DateTime CreatedAtUtc);
