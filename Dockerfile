# build image
FROM mcr.microsoft.com/dotnet/core/sdk:3.0 as build
WORKDIR /app

# copy csproj file
COPY aspnetcore-k8s.csproj .
RUN dotnet restore

# copy everything else and build app
COPY . .
WORKDIR /app
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/core/aspnet:3.0 as runtime
WORKDIR /app
COPY --from=build /app/out ./
ENV ASPNETCORE_URLS=https://+:443

# By specifying this here, when you run ASP.NET Core in "Dev" mode, it will use the localhost self-signed certificate,
# however, the Docker container will use the certificate listed below.  Best practice would be to NOT include the cert PFX
# file and the password here, but instead in Kubernetes secret objects, then populate those secrets into environment variables
# in your deployment YAML file instead
ENV ASPNETCORE_Kestrel__Certificates__Default__Password=P@ssw0rd
ENV ASPNETCORE_Kestrel__Certificates__Default__Path=/app/certs/aspnetcore-k8s.pfx
ENTRYPOINT ["dotnet", "aspnetcore-k8s.dll"]