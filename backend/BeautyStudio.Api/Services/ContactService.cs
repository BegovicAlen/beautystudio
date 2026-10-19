using System.Security.Claims;
using BeautyStudio.Api.Contracts.Contact;
using BeautyStudio.Api.Data;
using BeautyStudio.Api.Domain;
using BeautyStudio.Api.Exceptions;
using Microsoft.EntityFrameworkCore;
namespace BeautyStudio.Api.Services;
public sealed class ContactService(BeautyStudioDbContext db, IHttpContextAccessor accessor, NotificationComposer notifications)
{
    public async Task<ContactMessageResponse> CreateAsync(CreateContactMessageRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FullName) || string.IsNullOrWhiteSpace(request.Phone) || string.IsNullOrWhiteSpace(request.Message) || request.Message.Length > 3000 || string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@')) throw new BusinessException("Unesite ime, validan email, telefon i poruku do 3000 znakova.");
        var message = new ContactMessage { Id = Guid.NewGuid(), UserId = Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null, FullName = InputValidation.Text(request.FullName, "Ime i prezime", 150), Email = InputValidation.Email(request.Email), Phone = InputValidation.Phone(request.Phone), Message = InputValidation.Text(request.Message, "Poruka", 3000) };
        db.ContactMessages.Add(message);
        await notifications.StaffAsync(
            "ContactMessageReceived",
            "Nova poruka klijenta",
            $"{message.FullName} ({message.Email}) poslao/la je poruku salonu. Otvorite Poruke klijenata za detalje.",
            cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        return new ContactMessageResponse(message.Id, message.FullName, message.Email, message.Phone, message.Message, message.CreatedAtUtc);
    }
}
