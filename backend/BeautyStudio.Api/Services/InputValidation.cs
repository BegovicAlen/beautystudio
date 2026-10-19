using System.Net.Mail;
using System.Text.RegularExpressions;
using BeautyStudio.Api.Exceptions;

namespace BeautyStudio.Api.Services;

public static partial class InputValidation
{
    public static string Text(string? value, string field, int maximum)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Trim().Length > maximum)
            throw new BusinessException($"{field} je obavezno polje i može sadržavati najviše {maximum} znakova.");
        return value.Trim();
    }

    public static string Email(string? value)
    {
        var text = Text(value, "Email", 254).ToLowerInvariant();
        if (!MailAddress.TryCreate(text, out var parsed) || parsed.Address != text || !text.Split('@').Last().Contains('.'))
            throw new BusinessException("Unesite email u formatu ime@domena.com.");
        return text;
    }

    public static string Phone(string? value)
    {
        var text = Text(value, "Telefon", 30);
        if (!PhonePattern().IsMatch(text) || text.Count(char.IsDigit) is < 7 or > 15)
            throw new BusinessException("Telefon mora imati 7–15 cifara; dozvoljeni su početni +, razmaci, zagrade i crtice.");
        return text;
    }

    public static void Password(string? value)
    {
        if (value is null || value.Length is < 8 or > 72)
            throw new BusinessException("Lozinka mora sadržavati 8–72 znaka.");
    }

    [GeneratedRegex(@"^\+?[0-9 ()\-]+$")]
    private static partial Regex PhonePattern();
}
