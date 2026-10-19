FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY BeautyStudio.Api/BeautyStudio.Api.csproj BeautyStudio.Api/
COPY BeautyStudio.Worker/BeautyStudio.Worker.csproj BeautyStudio.Worker/
RUN dotnet restore BeautyStudio.Worker/BeautyStudio.Worker.csproj
COPY . .
RUN dotnet publish BeautyStudio.Worker/BeautyStudio.Worker.csproj -c Release -o /app/publish
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "BeautyStudio.Worker.dll"]
