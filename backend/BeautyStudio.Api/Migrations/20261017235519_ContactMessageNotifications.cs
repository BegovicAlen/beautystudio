using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class ContactMessageNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "NotificationTypes",
                columns: new[] { "Id", "Code", "IsActive", "Name" },
                values: new object[] { 1000, "ContactMessageReceived", true, "Nova poruka klijenta" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "NotificationTypes",
                keyColumn: "Id",
                keyValue: 1000);
        }
    }
}
