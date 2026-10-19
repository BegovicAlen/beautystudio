using BeautyStudio.Api.Domain;

namespace BeautyStudio.Api.Services;

public static class ReservationStateMachine
{
    public static bool CanTransition(ReservationStatus from, ReservationStatus to) => (from, to) switch
    {
        (ReservationStatus.Pending, ReservationStatus.Confirmed) => true,
        (ReservationStatus.Pending, ReservationStatus.Cancelled) => true,
        (ReservationStatus.Confirmed, ReservationStatus.Completed) => true,
        (ReservationStatus.Confirmed, ReservationStatus.Cancelled) => true,
        _ => false,
    };
}
