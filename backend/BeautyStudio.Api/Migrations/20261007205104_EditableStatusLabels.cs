using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class EditableStatusLabels : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey("FK_Reservations_ReservationStatuses_Status", "Reservations");
            migrationBuilder.DropIndex("IX_Reservations_Status", "Reservations");
            migrationBuilder.DropPrimaryKey("PK_ReservationStatuses", "ReservationStatuses");
            migrationBuilder.RenameTable("ReservationStatuses", newName: "ReservationStatusesLegacy");
            migrationBuilder.CreateTable(
                name: "ReservationStatuses",
                columns: table => new {
                    Id = table.Column<int>(type: "int", nullable: false).Annotation("SqlServer:Identity", "1, 1"),
                    Code = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table => table.PrimaryKey("PK_ReservationStatuses", x => x.Id));
            migrationBuilder.Sql("""
                SET IDENTITY_INSERT ReservationStatuses ON;
                INSERT INTO ReservationStatuses (Id, Code, Name, IsActive)
                SELECT CASE Id WHEN 'Pending' THEN 1 WHEN 'Confirmed' THEN 2 WHEN 'Cancelled' THEN 3 WHEN 'Completed' THEN 4 END,
                       Id, Name, IsActive
                FROM ReservationStatusesLegacy;
                SET IDENTITY_INSERT ReservationStatuses OFF;
                """);
            migrationBuilder.AddColumn<int>("StatusDefinitionId", "Reservations", type: "int", nullable: false, defaultValue: 1);
            migrationBuilder.Sql("""
                UPDATE Reservations SET StatusDefinitionId =
                  CASE Status WHEN 'Pending' THEN 1 WHEN 'Confirmed' THEN 2 WHEN 'Cancelled' THEN 3 WHEN 'Completed' THEN 4 END;
                """);
            migrationBuilder.CreateIndex("IX_Reservations_StatusDefinitionId", "Reservations", "StatusDefinitionId");
            migrationBuilder.AddForeignKey("FK_Reservations_ReservationStatuses_StatusDefinitionId", "Reservations", "StatusDefinitionId", "ReservationStatuses", principalColumn: "Id", onDelete: ReferentialAction.Restrict);
            migrationBuilder.DropTable("ReservationStatusesLegacy");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM ReservationStatuses WHERE Id > 4) THROW 51000, 'Remove unused custom status labels before rolling this migration back.', 1;");
            migrationBuilder.DropForeignKey("FK_Reservations_ReservationStatuses_StatusDefinitionId", "Reservations");
            migrationBuilder.DropIndex("IX_Reservations_StatusDefinitionId", "Reservations");
            migrationBuilder.DropColumn("StatusDefinitionId", "Reservations");
            migrationBuilder.DropPrimaryKey("PK_ReservationStatuses", "ReservationStatuses");
            migrationBuilder.RenameTable("ReservationStatuses", newName: "ReservationStatusesLegacy");
            migrationBuilder.CreateTable(
                name: "ReservationStatuses",
                columns: table => new {
                    Id = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table => table.PrimaryKey("PK_ReservationStatuses", x => x.Id));
            migrationBuilder.Sql("INSERT INTO ReservationStatuses (Id, Name, IsActive) SELECT Code, Name, IsActive FROM ReservationStatusesLegacy;");
            migrationBuilder.DropTable("ReservationStatusesLegacy");
            migrationBuilder.CreateIndex("IX_Reservations_Status", "Reservations", "Status");
            migrationBuilder.AddForeignKey("FK_Reservations_ReservationStatuses_Status", "Reservations", "Status", "ReservationStatuses", principalColumn: "Id", onDelete: ReferentialAction.Restrict);
        }
    }
}
