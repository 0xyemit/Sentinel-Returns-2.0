# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Data.ps1
# MÓDULO 1: Extracción de datos de mercado en tiempo real (Fix Objeto)

function Get-SentinelMarketData {
    # Lista definitiva de activos requeridos
    $Symbols = @("BTCUSDT", "ETHUSDT", "SOLUSDT", "ONDOUSDT", "HBARUSDT", "XRPUSDT", "TAOUSDT")
    $MarketPrices = @{}

    Write-Host "🔄 [DATA] Conectando con Binance para extraer precios en tiempo real..." -ForegroundColor Cyan

    foreach ($Symbol in $Symbols) {
        try {
            $Uri = "https://api.binance.com/api/v3/ticker/price?symbol=$Symbol"
            $Response = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 5
            
            $PriceRaw = [double]$Response.price
            # Si el precio es menor a $2 (ONDO, HBAR, XRP), dejamos 4 decimales para precisión quirúrgica
            if ($PriceRaw -lt 2.0) {
                $MarketPrices[$Symbol] = [math]::Round($PriceRaw, 4)
            } else {
                $MarketPrices[$Symbol] = [math]::Round($PriceRaw, 2)
            }
        }
        catch {
            Write-Host "⚠️ [DATA] Error al extraer precio de $Symbol. Usando 0.0" -ForegroundColor Yellow
            $MarketPrices[$Symbol] = 0.0
        }
    }

    # Extracción del Índice Fear & Greed Real
    try {
        $FngUri = "https://api.alternative.me/fng/"
        $FngResponse = Invoke-RestMethod -Uri $FngUri -Method Get -TimeoutSec 5
        $FngValue = $FngResponse.data[0].value
        $FngStatus = $FngResponse.data[0].value_classification
    }
    catch {
        $FngValue = "50"
        $FngStatus = "Neutral"
    }

    # Retornar objeto limpio sin duplicaciones
    return [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        BTC       = $MarketPrices["BTCUSDT"]
        ETH       = $MarketPrices["ETHUSDT"]
        SOL       = $MarketPrices["SOLUSDT"]
        ONDO      = $MarketPrices["ONDOUSDT"]
        HBAR      = $MarketPrices["HBARUSDT"]
        XRP       = $MarketPrices["XRPUSDT"]
        TAO       = $MarketPrices["TAOUSDT"]
        FnGValue  = $FngValue
        FnGStatus = $FngStatus
    }
}
