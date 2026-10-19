using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BeautyStudio.Api.Migrations
{
    /// <inheritdoc />
    public partial class EnforceRelationships : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_Users_UserId",
                table: "Notifications");

            migrationBuilder.DropForeignKey(
                name: "FK_ReservationStatusHistories_Reservations_ReservationId",
                table: "ReservationStatusHistories");

            migrationBuilder.DropForeignKey(
                name: "FK_ReservationStatusHistories_Users_ChangedById",
                table: "ReservationStatusHistories");

            migrationBuilder.DropForeignKey(
                name: "FK_Reviews_Reservations_ReservationId",
                table: "Reviews");

            migrationBuilder.DropForeignKey(
                name: "FK_Reviews_Services_ServiceId",
                table: "Reviews");

            migrationBuilder.DropForeignKey(
                name: "FK_Reviews_Users_UserId",
                table: "Reviews");

            migrationBuilder.DropForeignKey(
                name: "FK_UserActivities_Users_UserId",
                table: "UserActivities");

            migrationBuilder.DropIndex(
                name: "IX_Reviews_ReservationId",
                table: "Reviews");

            migrationBuilder.DropIndex(
                name: "IX_ReservationStatusHistories_ChangedById",
                table: "ReservationStatusHistories");

            migrationBuilder.DropColumn(
                name: "ChangedById",
                table: "ReservationStatusHistories");

            migrationBuilder.AlterColumn<string>(
                name: "Comment",
                table: "Reviews",
                type: "nvarchar(2000)",
                maxLength: 2000,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Title",
                table: "Notifications",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Message",
                table: "Notifications",
                type: "nvarchar(2000)",
                maxLength: 2000,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivities_BlogPostId",
                table: "UserActivities",
                column: "BlogPostId");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivities_CategoryId",
                table: "UserActivities",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivities_GalleryItemId",
                table: "UserActivities",
                column: "GalleryItemId");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivities_ServiceId",
                table: "UserActivities",
                column: "ServiceId");

            migrationBuilder.CreateIndex(
                name: "IX_Reviews_ReservationId",
                table: "Reviews",
                column: "ReservationId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ReservationStatusHistories_ChangedByUserId",
                table: "ReservationStatusHistories",
                column: "ChangedByUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_Users_UserId",
                table: "Notifications",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ReservationStatusHistories_Reservations_ReservationId",
                table: "ReservationStatusHistories",
                column: "ReservationId",
                principalTable: "Reservations",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ReservationStatusHistories_Users_ChangedByUserId",
                table: "ReservationStatusHistories",
                column: "ChangedByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Reviews_Reservations_ReservationId",
                table: "Reviews",
                column: "ReservationId",
                principalTable: "Reservations",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Reviews_Services_ServiceId",
                table: "Reviews",
                column: "ServiceId",
                principalTable: "Services",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Reviews_Users_UserId",
                table: "Reviews",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_UserActivities_BlogPosts_BlogPostId",
                table: "UserActivities",
                column: "BlogPostId",
                principalTable: "BlogPosts",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_UserActivities_GalleryItems_GalleryItemId",
                table: "UserActivities",
                column: "GalleryItemId",
                principalTable: "GalleryItems",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_UserActivities_ServiceCategories_CategoryId",
                table: "UserActivities",
                column: "CategoryId",
                principalTable: "ServiceCategories",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_UserActivities_Services_ServiceId",
                table: "UserActivities",
                column: "ServiceId",
                principalTable: "Services",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_UserActivities_Users_UserId",
                table: "UserActivities",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_Users_UserId",
                table: "Notifications");

            migrationBuilder.DropForeignKey(
                name: "FK_ReservationStatusHistories_Reservations_ReservationId",
                table: "ReservationStatusHistories");

            migrationBuilder.DropForeignKey(
                name: "FK_ReservationStatusHistories_Users_ChangedByUserId",
                table: "ReservationStatusHistories");

            migrationBuilder.DropForeignKey(
                name: "FK_Reviews_Reservations_ReservationId",
                table: "Reviews");

            migrationBuilder.DropForeignKey(
                name: "FK_Reviews_Services_ServiceId",
                table: "Reviews");

            migrationBuilder.DropForeignKey(
                name: "FK_Reviews_Users_UserId",
                table: "Reviews");

            migrationBuilder.DropForeignKey(
                name: "FK_UserActivities_BlogPosts_BlogPostId",
                table: "UserActivities");

            migrationBuilder.DropForeignKey(
                name: "FK_UserActivities_GalleryItems_GalleryItemId",
                table: "UserActivities");

            migrationBuilder.DropForeignKey(
                name: "FK_UserActivities_ServiceCategories_CategoryId",
                table: "UserActivities");

            migrationBuilder.DropForeignKey(
                name: "FK_UserActivities_Services_ServiceId",
                table: "UserActivities");

            migrationBuilder.DropForeignKey(
                name: "FK_UserActivities_Users_UserId",
                table: "UserActivities");

            migrationBuilder.DropIndex(
                name: "IX_UserActivities_BlogPostId",
                table: "UserActivities");

            migrationBuilder.DropIndex(
                name: "IX_UserActivities_CategoryId",
                table: "UserActivities");

            migrationBuilder.DropIndex(
                name: "IX_UserActivities_GalleryItemId",
                table: "UserActivities");

            migrationBuilder.DropIndex(
                name: "IX_UserActivities_ServiceId",
                table: "UserActivities");

            migrationBuilder.DropIndex(
                name: "IX_Reviews_ReservationId",
                table: "Reviews");

            migrationBuilder.DropIndex(
                name: "IX_ReservationStatusHistories_ChangedByUserId",
                table: "ReservationStatusHistories");

            migrationBuilder.AlterColumn<string>(
                name: "Comment",
                table: "Reviews",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(2000)",
                oldMaxLength: 2000,
                oldNullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ChangedById",
                table: "ReservationStatusHistories",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AlterColumn<string>(
                name: "Title",
                table: "Notifications",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(200)",
                oldMaxLength: 200);

            migrationBuilder.AlterColumn<string>(
                name: "Message",
                table: "Notifications",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(2000)",
                oldMaxLength: 2000);

            migrationBuilder.CreateIndex(
                name: "IX_Reviews_ReservationId",
                table: "Reviews",
                column: "ReservationId");

            migrationBuilder.CreateIndex(
                name: "IX_ReservationStatusHistories_ChangedById",
                table: "ReservationStatusHistories",
                column: "ChangedById");

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_Users_UserId",
                table: "Notifications",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_ReservationStatusHistories_Reservations_ReservationId",
                table: "ReservationStatusHistories",
                column: "ReservationId",
                principalTable: "Reservations",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_ReservationStatusHistories_Users_ChangedById",
                table: "ReservationStatusHistories",
                column: "ChangedById",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Reviews_Reservations_ReservationId",
                table: "Reviews",
                column: "ReservationId",
                principalTable: "Reservations",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Reviews_Services_ServiceId",
                table: "Reviews",
                column: "ServiceId",
                principalTable: "Services",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Reviews_Users_UserId",
                table: "Reviews",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserActivities_Users_UserId",
                table: "UserActivities",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
