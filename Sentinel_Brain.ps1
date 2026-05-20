# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Brain.ps1
# MÓDULO 2: Conexión con OpenRouter (UTF-8 nativo)

function Get-GeminiAnalysis {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MarketData,

        [Parameter(Mandatory = $true)]
        [string]$ApiKey,

        [Parameter(Mandatory = $false)]
        $Model = "deepseek/deepseek-chat"
    )

    Write-Host "🧠 [BRAIN] Conectando de forma nativa con OpenRouter..." -ForegroundColor Cyan

    $Prompt = @"
Eres el nucleo de inteligencia artificial de 'Sentinel Returns', un sistema avanzado enfocado en analisis cuantitativo y optimizacion de flujos de trading.

Procesa los siguientes datos de mercado EXTRAIDOS EN TIEMPO REAL:
- Fecha/Hora: $($MarketData.Timestamp)
- Bitcoin (BTC/USDT): $($MarketData.BTC)
- Ethereum (ETH/USDT): $($MarketData.ETH)
- Solana (SOL/USDT): $($MarketData.SOL)
- Ondo Finance (ONDO/USDT): $($MarketData.ONDO)
- Hedera (HBAR/USDT): $($MarketData.HBAR)
- Ripple (XRP/USDT): $($MarketData.XRP)
- Bittensor (TAO/USDT): $($MarketData.TAO)
- Indice Fear & Greed: $($MarketData.FnGValue) ($($MarketData.FnGStatus))

Genera un reporte diario de trading estructurado exactamente con las secciones que te indico abajo. Usa emojis estandar y escribe correctamente las tildes:

🛡️ **REPORTE DE VIGILANCIA SENTINEL**
*Monitoreo Intradía | $($MarketData.Timestamp)*
(Analiza brevemente el sentimiento del mercado según el Indice Fear & Greed actual y cómo afecta a los activos).

🪙 **ANÁLISIS DE ACTIVOS CORE**
• **BTC/USDT:** `$$($MarketData.BTC) -> Veredicto (COMPRA, VENTA o ESPERAR). Niveles de Stop Loss (SL) y Take Profit (TP).
• **ETH/USDT:** `$$($MarketData.ETH) -> Veredicto, SL y TP.
• **SOL/USDT:** `$$($MarketData.SOL) -> Veredicto, SL y TP.

🚀 **SELECCIÓN DE ALTCOINS E IA**
• **ONDO/USDT:** `$$($MarketData.ONDO) -> Veredicto, SL y TP.
• **HBAR/USDT:** `$$($MarketData.HBAR) -> Veredicto, SL y TP.
• **XRP/USDT:** `$$($MarketData.XRP) -> Veredicto, SL y TP.
• **TAO/USDT:** `$$($MarketData.TAO) -> Veredicto, SL y TP.

🛠️ **ACCIÓN DEL SENTINEL**
Define las 2 prioridades operativas o movimientos de gestion de riesgo clave para afrontar las próximas horas.

Responde de forma directa, fria y quirurgica en espanol. Evita cualquier texto introductorio, saludos o despedidas.
"@

    $BodyObj = @{
        model       = $Model
        messages    = @(@{ role = "user"; content = $Prompt })
        temperature = 0.3
    }

    $BodyJson = $BodyObj | ConvertTo-Json -Depth 10 -Compress

    $Headers = @{
        "Authorization" = "Bearer $ApiKey"
        "HTTP-Referer"  = "https://github.com/pabloecuaga/sentinel"
        "X-Title"       = "Sentinel Returns"
    }

    $Uri = "https://openrouter.ai/api/v1/chat/completions"

    try {
        $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($BodyJson)
        $WebResponse = Invoke-WebRequest -Uri $Uri -Method Post -Headers $Headers -ContentType "application/json; charset=utf-8" -Body $BodyBytes -TimeoutSec 45
        $ResponseText = [System.Text.Encoding]::UTF8.GetString($WebResponse.RawContentStream.ToArray())
        $Response = $ResponseText | ConvertFrom-Json

        if ($Response.choices[0].message.content) {
            return $Response.choices[0].message.content
        } else {
            return "ERROR: Contenido vacío desde la API."
        }
    }
    catch {
        Write-Host "❌ [BRAIN] Error de red en la llamada: $_" -ForegroundColor Red
        return "ERROR: Fallo de conexión."
    }
}
