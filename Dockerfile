# build image
FROM mcr.microsoft.com/dotnet/core/sdk:3.0 as build
WORKDIR /app

# copy csproj file
COPY aspnetcore-k8s.csproj .
RUN dotnet restore

# copy everything else and build app
COPY . .
WORKDIR /app
RUN dotnet publish aspnetcore-k8s.csproj -c Release -o out

FROM mcr.microsoft.com/dotnet/core/aspnet:3.0 as runtime
WORKDIR /app
COPY --from=build /app/out ./
RUN curl -LO https://github.com/DataDog/dd-trace-dotnet/releases/download/v1.24.0/datadog-dotnet-apm_1.24.0_amd64.deb
RUN dpkg -i ./datadog-dotnet-apm_1.24.0_amd64.deb

ENV CORECLR_ENABLE_PROFILING=1
ENV CORECLR_PROFILER={846F5F1C-F9AE-4B07-969E-05C26BC060D8}
ENV CORECLR_PROFILER_PATH=/opt/datadog/Datadog.Trace.ClrProfiler.Native.so
ENV DD_INTEGRATIONS=/opt/datadog/integrations.json
ENV DD_DOTNET_TRACER_HOME=/opt/datadog 
ENV ASPNETCORE_URLS=https://+:443

RUN /opt/datadog/createLogPath.sh

ENTRYPOINT ["dotnet", "aspnetcore-k8s.dll"]
