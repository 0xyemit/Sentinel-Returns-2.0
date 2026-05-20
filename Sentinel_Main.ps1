# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Main.ps1
# MASTER SCRIPT: Orquestador central de Sentinel Returns (UTF-8 GLOBAL BLINDAJE)

# FORZAR ENCODING UTF-8 GLOBAL EN LA CONSOLA DE WINDOWS Y POWERSHELL
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Forzar protocolo seguro para conexiones externas
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Cargar módulos funcionales de forma relativa
$CurrentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$CurrentDir\Sentinel_Data.ps1"
. "$CurrentDir\Sentinel_Brain.ps1"
. "$CurrentDir\Sentinel_Telegram.ps1"

function Start-SentinelPipeline {
    Write-Host "`n🛡️ === ARRANCANDO PIPELINE: SENTINEL RETURNS (UTF-8 SECURE) ===" -ForegroundColor White -BackgroundColor DarkBlue

    # Recuperar variables esenciales de entorno
    $CloudKey = $env:SENTINEL_CLOUD_KEY
    $TgToken  = $env:SENTINEL_TG_TOKEN
    $TgChatId = $env:SENTINEL_TG_CHATID

    if (-not $CloudKey) { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_CLOUD_KEY está vacía."; return }
    if (-not $TgToken)   { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_TG_TOKEN está vacía."; return }
    if (-not $TgChatId)  { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_TG_CHATID está vacía."; return }

    # 1. Extraer precios en tiempo real de Binance
    $MarketData = Get-SentinelMarketData
    if ($MarketData.BTC -eq 0.0) {
        Write-Host "⚠️ [MASTER] Alerta: Datos de mercado caídos. Cancelando ejecución." -ForegroundColor Red
        return
    }

    # 2. Procesar análisis con DeepSeek-V3 en OpenRouter
    $ReporteMarkdown = Get-GeminiAnalysis -MarketData $MarketData -ApiKey $CloudKey

    if ($ReporteMarkdown -like "ERROR:*") {
        Write-Host "⚠️ [MASTER] Alerta: El análisis falló. Abortando envío." -ForegroundColor Red
        return
    }

    # 3. Despachar a tu móvil por Telegram
    $ResultadoEnvio = Send-SentinelTelegramMessage -MessageText $ReporteMarkdown -Token $TgToken -ChatId $TgChatId

    if ($ResultadoEnvio) {
        Write-Host "🏁 [MASTER] Pipeline completado. ¡Reporte limpio enviado con éxito!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ [MASTER] El reporte se generó pero falló el envío por Telegram." -ForegroundColor Yellow
    }
}

Start-SentinelPipeline
