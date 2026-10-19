using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class ReviewCreatedNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "NotificationTypes",
                columns: new[] { "Id", "Code", "IsActive", "Name" },
                values: new object[] { 1001, "ReviewCreated", true, "Nova recenzija" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "NotificationTypes",
                keyColumn: "Id",
                keyValue: 1001);
        }
    }
}
