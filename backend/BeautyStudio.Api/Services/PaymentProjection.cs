using System.Linq.Expressions;
using BeautyStudio.Api.Contracts.Payments;
using BeautyStudio.Api.Domain;

namespace BeautyStudio.Api.Services;

public static class PaymentProjection
{
    public static Expression<Func<Payment, PaymentResponse>> Response => p => new PaymentResponse(p.Id, p.ReservationId, p.Reservation.User.FirstName + " " + p.Reservation.User.LastName, p.Reservation.Service.Name, p.Reservation.StartAtUtc, p.Amount + p.Transactions.Where(t => t.Kind == "OnSiteCharge").Sum(t => (decimal?)t.Amount).GetValueOrDefault(), p.Currency, p.Status.ToString(), p.CreatedAtUtc, p.PaidAtUtc, p.Provider, p.RefundedAmount, p.RefundedAtUtc, p.ReceiptUrl, p.Reservation.TotalAmount);
}
