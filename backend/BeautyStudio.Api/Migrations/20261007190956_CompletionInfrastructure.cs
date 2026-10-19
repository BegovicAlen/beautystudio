using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class CompletionInfrastructure : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                UPDATE ContactMessages SET UserId = NULL
                WHERE UserId IS NOT NULL AND (
                    TRY_CONVERT(uniqueidentifier, UserId) IS NULL OR
                    NOT EXISTS (SELECT 1 FROM Users WHERE Users.Id = TRY_CONVERT(uniqueidentifier, ContactMessages.UserId))
                );
                """);
            migrationBuilder.DropIndex(
                name: "IX_Payments_StripeCheckoutSessionId",
                table: "Payments");

            migrationBuilder.AddColumn<int>(
                name: "CityId",
                table: "Users",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "RecoveryCodeExpiresAtUtc",
                table: "Users",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RecoveryCodeHash",
                table: "Users",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TokenVersion",
                table: "Users",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "Address",
                table: "StudioAbouts",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "CityId",
                table: "StudioAbouts",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ClosingHour",
                table: "StudioAbouts",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "DepositPercent",
                table: "StudioAbouts",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "Email",
                table: "StudioAbouts",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "FoundedYear",
                table: "StudioAbouts",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "OpeningHour",
                table: "StudioAbouts",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "Phone",
                table: "StudioAbouts",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "ServiceCategories",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(450)");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Reservations",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AddColumn<string>(
                name: "Currency",
                table: "Reservations",
                type: "nvarchar(3)",
                maxLength: 3,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<decimal>(
                name: "TotalAmount",
                table: "Reservations",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AlterColumn<string>(
                name: "StripeCheckoutSessionId",
                table: "Payments",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(255)",
                oldMaxLength: 255);

            migrationBuilder.AddColumn<string>(
                name: "Provider",
                table: "Payments",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ReceiptUrl",
                table: "Payments",
                type: "nvarchar(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RefundedAmount",
                table: "Payments",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTime>(
                name: "RefundedAtUtc",
                table: "Payments",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StripeRefundId",
                table: "Payments",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NotificationTypeId",
                table: "Notifications",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CategoryId",
                table: "GalleryItems",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AlterColumn<Guid>(
                name: "UserId",
                table: "ContactMessages",
                type: "uniqueidentifier",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CategoryId",
                table: "BlogPosts",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "Cities",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Cities", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "NotificationTypes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Code = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NotificationTypes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PaymentTransactions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PaymentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    ProviderId = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    OccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PaymentTransactions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PaymentTransactions_Payments_PaymentId",
                        column: x => x.PaymentId,
                        principalTable: "Payments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ReservationStatuses",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReservationStatuses", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RevokedTokens",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RevokedTokens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RevokedTokens_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NotificationOutbox",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    NotificationTypeId = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Message = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    PublishedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NotificationOutbox", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NotificationOutbox_NotificationTypes_NotificationTypeId",
                        column: x => x.NotificationTypeId,
                        principalTable: "NotificationTypes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NotificationOutbox_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "Cities",
                columns: new[] { "Id", "IsActive", "Name" },
                values: new object[,]
                {
                    { 1, true, "Mostar" },
                    { 2, true, "Sarajevo" },
                    { 3, true, "Banja Luka" }
                });

            migrationBuilder.InsertData(
                table: "NotificationTypes",
                columns: new[] { "Id", "Code", "IsActive", "Name" },
                values: new object[,]
                {
                    { 1, "ReservationCreated", true, "Nova rezervacija" },
                    { 2, "ReservationStatusChanged", true, "Promjena statusa rezervacije" },
                    { 3, "PaymentReceived", true, "Plaćanje" },
                    { 4, "PaymentRefunded", true, "Povrat sredstava" },
                    { 5, "AccountSecurity", true, "Sigurnost naloga" }
                });

            migrationBuilder.InsertData(
                table: "ReservationStatuses",
                columns: new[] { "Id", "IsActive", "Name" },
                values: new object[,]
                {
                    { "Cancelled", true, "Otkazano" },
                    { "Completed", true, "Završeno" },
                    { "Confirmed", true, "Potvrđeno" },
                    { "Pending", true, "Na čekanju" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_CityId",
                table: "Users",
                column: "CityId");

            migrationBuilder.CreateIndex(
                name: "IX_StudioAbouts_CityId",
                table: "StudioAbouts",
                column: "CityId");

            migrationBuilder.CreateIndex(
                name: "IX_Reservations_Status",
                table: "Reservations",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_Payments_StripeCheckoutSessionId",
                table: "Payments",
                column: "StripeCheckoutSessionId",
                unique: true,
                filter: "[StripeCheckoutSessionId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_NotificationTypeId",
                table: "Notifications",
                column: "NotificationTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_GalleryItems_CategoryId",
                table: "GalleryItems",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_ContactMessages_UserId",
                table: "ContactMessages",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_BlogPosts_CategoryId",
                table: "BlogPosts",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_Cities_Name",
                table: "Cities",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_NotificationOutbox_NotificationTypeId",
                table: "NotificationOutbox",
                column: "NotificationTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationOutbox_PublishedAtUtc",
                table: "NotificationOutbox",
                column: "PublishedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationOutbox_UserId",
                table: "NotificationOutbox",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationTypes_Code",
                table: "NotificationTypes",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_PaymentId",
                table: "PaymentTransactions",
                column: "PaymentId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_ProviderId",
                table: "PaymentTransactions",
                column: "ProviderId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RevokedTokens_UserId",
                table: "RevokedTokens",
                column: "UserId");

            migrationBuilder.Sql("""
                INSERT INTO ServiceCategories (Name, IsActive)
                SELECT DISTINCT LEFT(g.Category, 150), 1 FROM GalleryItems g
                WHERE LEN(LTRIM(RTRIM(g.Category))) > 0 AND NOT EXISTS
                    (SELECT 1 FROM ServiceCategories c WHERE c.Name = LEFT(g.Category, 150));
                IF NOT EXISTS (SELECT 1 FROM ServiceCategories) AND
                   (EXISTS (SELECT 1 FROM GalleryItems) OR EXISTS (SELECT 1 FROM BlogPosts))
                    INSERT INTO ServiceCategories (Name, IsActive) VALUES (N'Opće', 1);
                UPDATE g SET CategoryId = COALESCE(c.Id, (SELECT MIN(Id) FROM ServiceCategories))
                FROM GalleryItems g LEFT JOIN ServiceCategories c ON c.Name = LEFT(g.Category, 150);
                UPDATE b SET CategoryId = COALESCE(
                    (SELECT TOP 1 Id FROM ServiceCategories c WHERE
                        (b.Title LIKE N'%manik%' AND c.Name = N'Nokti') OR
                        (b.Title LIKE N'%kos%' AND c.Name = N'Frizura') OR
                        (b.Title LIKE N'%obrv%' AND c.Name = N'Obrve') OR
                        (b.Title LIKE N'%makeup%' AND c.Name = N'Makeup')),
                    (SELECT MIN(Id) FROM ServiceCategories)) FROM BlogPosts b;
                UPDATE r SET TotalAmount = COALESCE(p.Amount, s.Price), Currency = COALESCE(NULLIF(p.Currency, ''), 'bam')
                FROM Reservations r INNER JOIN Services s ON s.Id = r.ServiceId
                LEFT JOIN Payments p ON p.ReservationId = r.Id AND p.Status = 'Paid';
                UPDATE Payments SET Provider = 'Stripe';
                INSERT INTO PaymentTransactions (Id, PaymentId, Kind, ProviderId, Amount, OccurredAtUtc)
                SELECT NEWID(), Id, 'Charge', COALESCE(StripePaymentIntentId, 'legacy-' + CONVERT(varchar(36), Id)), Amount, COALESCE(PaidAtUtc, CreatedAtUtc)
                FROM Payments WHERE Status = 'Paid';
                UPDATE StudioAbouts SET OpeningHour = 9, ClosingHour = 20, DepositPercent = 100, FoundedYear = 2020, CityId = 1;
                """);
            migrationBuilder.DropColumn(
                name: "Category",
                table: "GalleryItems");

            migrationBuilder.AddForeignKey(
                name: "FK_BlogPosts_ServiceCategories_CategoryId",
                table: "BlogPosts",
                column: "CategoryId",
                principalTable: "ServiceCategories",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ContactMessages_Users_UserId",
                table: "ContactMessages",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_GalleryItems_ServiceCategories_CategoryId",
                table: "GalleryItems",
                column: "CategoryId",
                principalTable: "ServiceCategories",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_NotificationTypes_NotificationTypeId",
                table: "Notifications",
                column: "NotificationTypeId",
                principalTable: "NotificationTypes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Reservations_ReservationStatuses_Status",
                table: "Reservations",
                column: "Status",
                principalTable: "ReservationStatuses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_StudioAbouts_Cities_CityId",
                table: "StudioAbouts",
                column: "CityId",
                principalTable: "Cities",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Users_Cities_CityId",
                table: "Users",
                column: "CityId",
                principalTable: "Cities",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_BlogPosts_ServiceCategories_CategoryId",
                table: "BlogPosts");

            migrationBuilder.DropForeignKey(
                name: "FK_ContactMessages_Users_UserId",
                table: "ContactMessages");

            migrationBuilder.DropForeignKey(
                name: "FK_GalleryItems_ServiceCategories_CategoryId",
                table: "GalleryItems");

            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_NotificationTypes_NotificationTypeId",
                table: "Notifications");

            migrationBuilder.DropForeignKey(
                name: "FK_Reservations_ReservationStatuses_Status",
                table: "Reservations");

            migrationBuilder.DropForeignKey(
                name: "FK_StudioAbouts_Cities_CityId",
                table: "StudioAbouts");

            migrationBuilder.DropForeignKey(
                name: "FK_Users_Cities_CityId",
                table: "Users");

            migrationBuilder.DropTable(
                name: "Cities");

            migrationBuilder.DropTable(
                name: "NotificationOutbox");

            migrationBuilder.DropTable(
                name: "PaymentTransactions");

            migrationBuilder.DropTable(
                name: "ReservationStatuses");

            migrationBuilder.DropTable(
                name: "RevokedTokens");

            migrationBuilder.DropTable(
                name: "NotificationTypes");

            migrationBuilder.DropIndex(
                name: "IX_Users_CityId",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_StudioAbouts_CityId",
                table: "StudioAbouts");

            migrationBuilder.DropIndex(
                name: "IX_Reservations_Status",
                table: "Reservations");

            migrationBuilder.DropIndex(
                name: "IX_Payments_StripeCheckoutSessionId",
                table: "Payments");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_NotificationTypeId",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_GalleryItems_CategoryId",
                table: "GalleryItems");

            migrationBuilder.DropIndex(
                name: "IX_ContactMessages_UserId",
                table: "ContactMessages");

            migrationBuilder.DropIndex(
                name: "IX_BlogPosts_CategoryId",
                table: "BlogPosts");

            migrationBuilder.DropColumn(
                name: "CityId",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RecoveryCodeExpiresAtUtc",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RecoveryCodeHash",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "TokenVersion",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Address",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "CityId",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "ClosingHour",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "DepositPercent",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "Email",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "FoundedYear",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "OpeningHour",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "Phone",
                table: "StudioAbouts");

            migrationBuilder.DropColumn(
                name: "Currency",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "TotalAmount",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "Provider",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "ReceiptUrl",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "RefundedAmount",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "RefundedAtUtc",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "StripeRefundId",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "NotificationTypeId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "GalleryItems");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "BlogPosts");

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "ServiceCategories",
                type: "nvarchar(450)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(150)",
                oldMaxLength: 150);

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Reservations",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "StripeCheckoutSessionId",
                table: "Payments",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "nvarchar(255)",
                oldMaxLength: 255,
                oldNullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Category",
                table: "GalleryItems",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "ContactMessages",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Payments_StripeCheckoutSessionId",
                table: "Payments",
                column: "StripeCheckoutSessionId",
                unique: true);
        }
    }
}
