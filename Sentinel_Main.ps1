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
    $OllamaKey    = $env:SENTINEL_OLLAMA_KEY
    $TgToken      = $env:SENTINEL_TG_TOKEN
    $TgChatId     = $env:SENTINEL_TG_CHATID
    $CoinCapKey   = $env:SENTINEL_COINCAP_KEY

    if (-not $OllamaKey)  { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_OLLAMA_KEY está vacía."; return }
    if (-not $TgToken)    { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_TG_TOKEN está vacía."; return }
    if (-not $TgChatId)   { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_TG_CHATID está vacía."; return }
    if (-not $CoinCapKey) { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_COINCAP_KEY está vacía."; return }

    # 1. Extraer precios en tiempo real de Binance
    $MarketData = Get-SentinelMarketData
    if ($MarketData.BTC -eq 0.0) {
        Write-Host "⚠️ [MASTER] Alerta: Datos de mercado caídos. Cancelando ejecución." -ForegroundColor Red
        return
    }

    # 2. Procesar análisis con DeepSeek-V3 en Ollama Cloud
    $ReporteMarkdown = Get-GeminiAnalysis -MarketData $MarketData -ApiKey $OllamaKey

    if (@($ReporteMarkdown)[0] -like "ERROR:*") {
        Write-Host "⚠️ [MASTER] Alerta: El análisis falló. Abortando envío." -ForegroundColor Red
        return
    }

    # 3. Despachar a tu móvil por Telegram (2 mensajes)
    $TodosEnviados = $true
    foreach ($Msg in $ReporteMarkdown) {
        $Ok = Send-SentinelTelegramMessage -MessageText $Msg -Token $TgToken -ChatId $TgChatId
        if (-not $Ok) { $TodosEnviados = $false }
        Start-Sleep -Milliseconds 800
    }

    if ($TodosEnviados) {
        Write-Host "🏁 [MASTER] Pipeline completado. ¡Reporte limpio enviado con éxito!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ [MASTER] El reporte se generó pero falló algún envío por Telegram." -ForegroundColor Yellow
    }
}

Start-SentinelPipeline
