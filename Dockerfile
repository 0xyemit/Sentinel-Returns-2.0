FROM mcr.microsoft.com/powershell:lts-ubuntu-22.04

# Instalar tzdata para soporte de zonas horarias (Europe/Madrid)
RUN apt-get update && apt-get install -y tzdata && rm -rf /var/lib/apt/lists/*
ENV TZ=Europe/Madrid

WORKDIR /app

# Copiar solo los scripts necesarios (el .env NO se incluye — vars vienen de Cloud Run)
COPY Sentinel_Main.ps1 .
COPY Sentinel_Data.ps1 .
COPY Sentinel_Brain.ps1 .
COPY Sentinel_Telegram.ps1 .
COPY Sentinel_Server.ps1 .

# Cloud Run inyecta $PORT en tiempo de ejecucion (normalmente 8080)
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["pwsh", "-ExecutionPolicy", "Bypass", "-File", "Sentinel_Main.ps1", "-Webhook"]
