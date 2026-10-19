FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["BeautyStudio.Api/BeautyStudio.Api.csproj", "BeautyStudio.Api/"]
RUN dotnet restore "BeautyStudio.Api/BeautyStudio.Api.csproj"
COPY . .
RUN dotnet publish "BeautyStudio.Api/BeautyStudio.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "BeautyStudio.Api.dll"]
