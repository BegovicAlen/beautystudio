using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddInformationContent : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "FaqEntries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Question = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    Answer = table.Column<string>(type: "nvarchar(3000)", maxLength: 3000, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FaqEntries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "StudioAbouts",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Content = table.Column<string>(type: "nvarchar(max)", maxLength: 5000, nullable: false),
                    ImageUrl = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StudioAbouts", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "StudioAbouts",
                columns: new[] { "Id", "Title", "Content", "ImageUrl" },
                values: new object[] { 1, "BeautyStudio", "BeautyStudio omogućava pregled tretmana, online rezervacije, galeriju radova i upravljanje terminima na jednom mjestu.", null });

            migrationBuilder.InsertData(
                table: "FaqEntries",
                columns: new[] { "Id", "Question", "Answer", "IsActive", "SortOrder" },
                values: new object[,]
                {
                    { new Guid("fd60bf54-0b4e-4d00-8ac3-087cdb284d00"), "Kako rezervisati termin?", "Otvorite uslugu, odaberite datum i vrijeme, zatim potvrdite rezervaciju.", true, 1 },
                    { new Guid("9e4d5248-2c8c-4da6-9b33-8d23c9ccfde7"), "Zašto termin nije dostupan?", "Termin nije dostupan kada se preklapa s postojećom aktivnom rezervacijom.", true, 2 },
                    { new Guid("9f14d23a-8386-463e-89c0-a5a0d6231e22"), "Kako otkazati termin?", "U dijelu Moji termini odaberite rezervaciju i navedite razlog otkazivanja.", true, 3 },
                    { new Guid("5fc4998c-0fd3-482e-b502-564342d92c81"), "Kada mogu ostaviti recenziju?", "Recenziju možete ostaviti samo za termin čiji je status Završeno.", true, 4 },
                    { new Guid("1dfbbc41-0e2c-4f2d-9826-6dbdcc776d18"), "Kako isključiti obavijesti?", "Otvorite Moj profil i isključite postavku Primajte obavijesti.", true, 5 }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "FaqEntries");

            migrationBuilder.DropTable(
                name: "StudioAbouts");
        }
    }
}
