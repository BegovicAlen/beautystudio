using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class LinkFaqToStudio : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "StudioAboutId",
                table: "FaqEntries",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_FaqEntries_StudioAboutId",
                table: "FaqEntries",
                column: "StudioAboutId");

            migrationBuilder.AddForeignKey(
                name: "FK_FaqEntries_StudioAbouts_StudioAboutId",
                table: "FaqEntries",
                column: "StudioAboutId",
                principalTable: "StudioAbouts",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_FaqEntries_StudioAbouts_StudioAboutId",
                table: "FaqEntries");

            migrationBuilder.DropIndex(
                name: "IX_FaqEntries_StudioAboutId",
                table: "FaqEntries");

            migrationBuilder.DropColumn(
                name: "StudioAboutId",
                table: "FaqEntries");
        }
    }
}
