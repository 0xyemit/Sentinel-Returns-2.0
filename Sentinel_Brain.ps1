# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Brain.ps1
# MÓDULO 2: Conexión con OpenRouter (UTF-8 nativo)

function Get-Indicators {
    param([string]$CoinCapId)

    $ApiKey = $env:SENTINEL_COINCAP_KEY
    $Now    = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $Base   = "https://rest.coincap.io/v3/assets/$CoinCapId/history"

    # Daily history — 310 días para EMA200 estable
    $D310    = [DateTimeOffset]::UtcNow.AddDays(-310).ToUnixTimeMilliseconds()
    $Daily   = Invoke-RestMethod -Uri "$Base`?interval=d1&start=$D310&end=$Now&apiKey=$ApiKey" -TimeoutSec 15
    $Closes  = $Daily.data | ForEach-Object { [decimal]$_.priceUsd }

    # h6 history — 35 días para RSI14 (intervalo más granular disponible en v3)
    $H6Start   = [DateTimeOffset]::UtcNow.AddDays(-35).ToUnixTimeMilliseconds()
    $H6        = Invoke-RestMethod -Uri "$Base`?interval=h6&start=$H6Start&end=$Now&apiKey=$ApiKey" -TimeoutSec 15
    $RSICloses = $H6.data | ForEach-Object { [decimal]$_.priceUsd }
    if ($RSICloses.Count -lt 15) { $RSICloses = $Closes }

    function Get-EMA {
        param([decimal[]]$Data, [int]$Period)
        $K = 2 / ($Period + 1); $EMA = $Data[0]
        foreach ($Val in $Data[1..($Data.Count-1)]) { $EMA = ($Val * $K) + ($EMA * (1 - $K)) }
        return [math]::Round($EMA, 2)
    }

    function Get-RSI {
        param([decimal[]]$Data, [int]$Period = 14)
        $G = 0.0; $L = 0.0
        for ($i = 1; $i -le $Period; $i++) {
            $D = $Data[$i] - $Data[$i-1]
            if ($D -gt 0) { $G += $D } else { $L += [math]::Abs($D) }
        }
        $AvgG = $G / $Period; $AvgL = $L / $Period
        if ($AvgL -eq 0) { return 100 }
        return [math]::Round(100 - (100 / (1 + ($AvgG / $AvgL))), 1)
    }

    return [PSCustomObject]@{
        EMA200 = Get-EMA $Closes 200
        RSI    = Get-RSI $RSICloses 14
    }
}

function ConvertTo-HtmlSafe {
    param([string]$Text)
    return $Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
}

function Get-RSIZone {
    param([string]$RSIVal)
    if ($RSIVal -eq "N/A") { return "N/A" }
    $R = [decimal]$RSIVal
    if ($R -le 30) { return "sobreventa" }
    if ($R -le 49) { return "débil" }
    if ($R -le 69) { return "neutro" }
    if ($R -le 74) { return "alto" }
    return "sobrecompra"
}

function Get-EMAStatus {
    param([string]$Price, [string]$EMA)
    if ($EMA -eq "N/A" -or [string]::IsNullOrWhiteSpace($Price)) { return "⚪ EMA N/A" }
    try {
        $P = [decimal]($Price -replace '[,$\s]', '')
        $E = [decimal]($EMA   -replace '[,$\s]', '')
        if ($P -gt $E) { return "✅ precio &gt; EMA200" } else { return "❌ precio &lt; EMA200" }
    } catch { return "⚪ EMA N/A" }
}

function Get-VerdictEmoji {
    param([string]$Verdict)
    switch ($Verdict) {
        "COMPRA"  { return "🟢" }
        "VENTA"   { return "🔴" }
        "ESPERAR" { return "🟡" }
        "CAUTELA" { return "🟠" }
        "REDUCIR" { return "🔵" }
        default   { return "⚪" }
    }
}

function Format-AssetCard {
    param(
        [string]$Symbol,
        [PSCustomObject]$Ind,
        [string]$Price,
        [string]$Emoji,
        [PSCustomObject]$AData
    )
    $Zone     = Get-RSIZone ([string]$Ind.RSI)
    $EmaS     = Get-EMAStatus $Price ([string]$Ind.EMA200)
    $VEmoji   = Get-VerdictEmoji $AData.verdict
    $SLRaw  = if ($AData.sl  -eq "N/A") { "N/A" } else { "`$$($AData.sl)" }
    $TP1Raw = if ($AData.tp1 -eq "N/A") { "N/A" } else { "`$$($AData.tp1)" }
    $TP2Raw = if ($AData.tp2 -eq "N/A") { "N/A" } else { "`$$($AData.tp2)" }
    $Analysis = ConvertTo-HtmlSafe $AData.analysis
    $L1 = "$Emoji <b>$Symbol/USDT</b>"
    $L2 = "<code>`$$Price · EMA200: `$$($Ind.EMA200) · RSI: $($Ind.RSI)</code>"
    $L3 = "$EmaS  📊 RSI $Zone $($Ind.RSI)"
    $L4 = $Analysis
    $L5 = "SL: <code>$SLRaw</code>  ·  TP1: <code>$TP1Raw</code>  ·  TP2: <code>$TP2Raw</code>"
    $L6 = "$VEmoji <b>$($AData.verdict)</b>"
    return "$L1`n$L2`n$L3`n`n$L4`n$L5`n$L6"
}

function Get-GeminiAnalysis {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MarketData,

        [Parameter(Mandatory = $true)]
        [string]$ApiKey,

        [Parameter(Mandatory = $false)]
        $Model = "deepseek-v3"
    )

    Write-Host "🧠 [BRAIN] Conectando con Ollama local..." -ForegroundColor Cyan

    $CoinMap = @{
        BTC  = "bitcoin"
        ETH  = "ethereum"
        SOL  = "solana"
        ONDO = "ondo-finance"
        HBAR = "hedera-hashgraph"
        XRP  = "xrp"
        TAO  = "bittensor"
    }

    Write-Host "📊 [BRAIN] Calculando indicadores técnicos (CoinCap)..." -ForegroundColor Cyan
    $Indicators = @{}
    foreach ($Asset in $CoinMap.Keys) {
        Start-Sleep -Milliseconds 500
        try {
            $Indicators[$Asset] = Get-Indicators $CoinMap[$Asset]
            Write-Host "  ✓ $Asset → EMA200: $($Indicators[$Asset].EMA200) | RSI: $($Indicators[$Asset].RSI)" -ForegroundColor DarkGray
        } catch {
            Write-Host "  ⚠️ $Asset → Fallo, usando N/A" -ForegroundColor Yellow
            $Indicators[$Asset] = [PSCustomObject]@{ EMA200 = "N/A"; RSI = "N/A" }
        }
    }

    $Prompt = @"
Eres el nucleo de inteligencia artificial de 'Sentinel Returns'. Analiza los datos y devuelve UNICAMENTE un objeto JSON valido, sin texto extra, sin markdown, sin bloques de codigo.

DATOS DE MERCADO EN TIEMPO REAL:
- Fecha/Hora: $($MarketData.Timestamp)
- Bitcoin (BTC/USDT): $($MarketData.BTC) | EMA200: $($Indicators['BTC'].EMA200) | RSI: $($Indicators['BTC'].RSI)
- Ethereum (ETH/USDT): $($MarketData.ETH) | EMA200: $($Indicators['ETH'].EMA200) | RSI: $($Indicators['ETH'].RSI)
- Solana (SOL/USDT): $($MarketData.SOL) | EMA200: $($Indicators['SOL'].EMA200) | RSI: $($Indicators['SOL'].RSI)
- Ondo Finance (ONDO/USDT): $($MarketData.ONDO) | EMA200: $($Indicators['ONDO'].EMA200) | RSI: $($Indicators['ONDO'].RSI)
- Hedera (HBAR/USDT): $($MarketData.HBAR) | EMA200: $($Indicators['HBAR'].EMA200) | RSI: $($Indicators['HBAR'].RSI)
- Ripple (XRP/USDT): $($MarketData.XRP) | EMA200: $($Indicators['XRP'].EMA200) | RSI: $($Indicators['XRP'].RSI)
- Bittensor (TAO/USDT): $($MarketData.TAO) | EMA200: $($Indicators['TAO'].EMA200) | RSI: $($Indicators['TAO'].RSI)
- Indice Fear & Greed: $($MarketData.FnGValue) ($($MarketData.FnGStatus))

MATRIZ DE DECISION (aplica en este orden, sin excepciones):

CONDICION ALCISTA — precio > EMA200:
- RSI < 70: COMPRA valida
- RSI 70-74: CAUTELA obligatorio (no abrir nueva posicion, timing suboptimo)
- RSI >= 75: REDUCIR si hay posicion abierta / ESPERAR si no hay posicion

CONDICION BAJISTA — precio < EMA200:
- RSI >= 55: VENTA valida (tendencia bajista activa con momentum confirmado)
- RSI 25-54: ESPERAR (debilidad sin catalizador claro, sin momentum vendedor)
- RSI < 25: ESPERAR (sobreventa extrema, no perseguir la caida)

EXCEPCION CAPITULACION:
- precio < EMA200 + RSI < 25 + Fear & Greed < 20: COMPRA tactica admitida

DATOS AUSENTES:
- Si EMA200 o RSI = N/A: veredicto basado unicamente en precio spot y Fear & Greed

En el analisis de cada activo menciona siempre: condicion EMA (alcista/bajista), zona RSI y veredicto resultante con su justificacion.

Veredictos disponibles: COMPRA, VENTA, ESPERAR, CAUTELA, REDUCIR
Responde en espanol. Analisis concisos y quirurgicos.

CALCULO DE SL Y TP (obligatorio para COMPRA y VENTA, N/A para el resto):

SL — nivel de invalidacion tecnica:
- Usa el nivel tecnico mas cercano que invalide la operacion (EMA200, soporte/resistencia clave, numero redondo)
- Si no hay nivel claro: SL = precio_entrada +/- 3% para BTC/ETH/SOL/XRP, +/- 5% para ONDO/HBAR/TAO
- VENTA: SL siempre ENCIMA del precio de entrada
- COMPRA: SL siempre DEBAJO del precio de entrada

TP1 y TP2 — proporcionales al riesgo:
- Calcula distancia_SL = abs(precio_entrada - sl)
- TP1 = precio_entrada -/+ (distancia_SL x 2)   → ratio 1:2 minimo obligatorio
- TP2 = precio_entrada -/+ (distancia_SL x 4)   → ratio 1:4 objetivo
- VENTA: TP1 y TP2 DEBAJO del precio de entrada
- COMPRA: TP1 y TP2 ENCIMA del precio de entrada
- Usa numeros redondeados a niveles tecnicos cuando coincidan con el calculo

JSON de respuesta (exactamente esta estructura, sin texto extra):
{
  "market_commentary": "2-3 frases sobre sentimiento de mercado",
  "assets": {
    "BTC":  { "verdict": "VENTA",   "analysis": "razonamiento con filtros si aplican", "sl": "79500",  "tp1": "72900", "tp2": "69300" },
    "ETH":  { "verdict": "ESPERAR", "analysis": "...", "sl": "N/A", "tp1": "N/A", "tp2": "N/A" },
    "SOL":  { "verdict": "VENTA",   "analysis": "...", "sl": "valor", "tp1": "valor", "tp2": "valor" },
    "ONDO": { "verdict": "...", "analysis": "...", "sl": "...", "tp1": "...", "tp2": "..." },
    "HBAR": { "verdict": "...", "analysis": "...", "sl": "...", "tp1": "...", "tp2": "..." },
    "XRP":  { "verdict": "...", "analysis": "...", "sl": "...", "tp1": "...", "tp2": "..." },
    "TAO":  { "verdict": "...", "analysis": "...", "sl": "...", "tp1": "...", "tp2": "..." }
  },
  "priorities": [
    "Primera prioridad operativa",
    "Segunda prioridad operativa"
  ]
}
"@

    $BodyObj = @{
        model       = $Model
        messages    = @(@{ role = "user"; content = $Prompt })
        temperature = 0.3
    }

    $BodyJson = $BodyObj | ConvertTo-Json -Depth 10 -Compress

    $Headers = @{
        "Authorization" = "Bearer $ApiKey"
    }

    $Uri = "http://localhost:11434/v1/chat/completions"

    try {
        $BodyBytes    = [System.Text.Encoding]::UTF8.GetBytes($BodyJson)
        $WebResponse  = Invoke-WebRequest -Uri $Uri -Method Post -Headers $Headers -ContentType "application/json; charset=utf-8" -Body $BodyBytes -TimeoutSec 120
        $ResponseText = [System.Text.Encoding]::UTF8.GetString($WebResponse.RawContentStream.ToArray())
        $Response     = $ResponseText | ConvertFrom-Json

        if (-not $Response.choices[0].message.content) {
            return @("ERROR: Contenido vacío desde la API.")
        }

        # Strip markdown fences if LLM wrapped the JSON
        $RawJson = ($Response.choices[0].message.content -replace '(?s)```json\s*|\s*```', '').Trim()

        try {
            $Data = $RawJson | ConvertFrom-Json
        } catch {
            Write-Host "⚠️ [BRAIN] JSON inválido recibido." -ForegroundColor Yellow
            return @("ERROR: La IA no devolvió JSON válido.")
        }

        # Lookup tables for card formatting
        $AssetEmoji  = @{ BTC="₿"; ETH="Ξ"; SOL="◎"; ONDO="💠"; HBAR="🔷"; XRP="💧"; TAO="🧠" }
        $AssetPrices = @{
            BTC=$MarketData.BTC; ETH=$MarketData.ETH; SOL=$MarketData.SOL
            ONDO=$MarketData.ONDO; HBAR=$MarketData.HBAR; XRP=$MarketData.XRP; TAO=$MarketData.TAO
        }

        # Pre-build all 7 asset cards
        $Cards = @{}
        foreach ($Sym in @("BTC","ETH","SOL","ONDO","HBAR","XRP","TAO")) {
            $Cards[$Sym] = Format-AssetCard $Sym $Indicators[$Sym] $AssetPrices[$Sym] $AssetEmoji[$Sym] ($Data.assets.$Sym)
        }

        # HTML-escape LLM text fields used directly in messages
        $Commentary = ConvertTo-HtmlSafe $Data.market_commentary
        $P1         = ConvertTo-HtmlSafe $Data.priorities[0]
        $P2         = ConvertTo-HtmlSafe $Data.priorities[1]

        # Fear & Greed contextual emoji
        $FnGVal   = [int]$MarketData.FnGValue
        $FnGEmoji = if ($FnGVal -le 25) { "😱" } elseif ($FnGVal -le 45) { "😨" } elseif ($FnGVal -le 55) { "😐" } elseif ($FnGVal -le 75) { "😏" } else { "🤑" }
        $Sep  = "━━━━━━━━━━━━━━━━━━━━"
        $Line = "──────────────────"

        $Msg1 = @"
$Sep
🛡️ <b>REPORTE DE VIGILANCIA SENTINEL</b>
📅 $($MarketData.Timestamp)

$FnGEmoji <b>Fear &amp; Greed</b>
$($MarketData.FnGValue) — <b>$($MarketData.FnGStatus)</b>

$Commentary

$Sep
🪙 <b>ACTIVOS CORE</b>

$($Cards['BTC'])
$Line
$($Cards['ETH'])
$Line
$($Cards['SOL'])
"@

        $Msg2 = @"
🚀 <b>ALTCOINS E IA</b>

$($Cards['ONDO'])
$Line
$($Cards['HBAR'])
$Line
$($Cards['XRP'])
$Line
$($Cards['TAO'])

$Sep
🛠️ <b>ACCIÓN DEL SENTINEL</b>

<b>01 ·</b> $P1

<b>02 ·</b> $P2
"@

        return @($Msg1, $Msg2)
    }
    catch {
        Write-Host "❌ [BRAIN] Error de red en la llamada: $_" -ForegroundColor Red
        return @("ERROR: Fallo de conexión.")
    }
}
