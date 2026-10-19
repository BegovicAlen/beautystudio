using BeautyStudio.Api.Domain;
namespace BeautyStudio.Api.Contracts.Reservations;
public sealed record ChangeReservationStatusRequest(ReservationStatus Status, string Reason, int? StatusDefinitionId = null);
