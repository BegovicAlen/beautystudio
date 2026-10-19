using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddReservationPaymentMethod : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PaymentMethod",
                table: "Reservations",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "OnSite");

            migrationBuilder.Sql("""
                UPDATE reservation
                SET PaymentMethod = 'Card'
                FROM Reservations AS reservation
                INNER JOIN Payments AS payment ON payment.ReservationId = reservation.Id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PaymentMethod",
                table: "Reservations");
        }
    }
}
