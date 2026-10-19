using BeautyStudio.Api.Domain;

namespace BeautyStudio.Api.Contracts.Reservations;
public sealed record CreateReservationRequest(int ServiceId, DateTime StartAtUtc, ReservationPaymentMethod PaymentMethod = ReservationPaymentMethod.OnSite);
