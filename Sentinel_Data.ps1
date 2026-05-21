# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Data.ps1
# MÓDULO 1: Extracción de datos de mercado en tiempo real (CoinGecko API)

function Get-SentinelMarketData {
    Write-Host "🔄 [DATA] Conectando con CoinGecko para extraer precios en tiempo real..." -ForegroundColor Cyan

    $Prices = @{ BTC = 0.0; ETH = 0.0; SOL = 0.0; ONDO = 0.0; HBAR = 0.0; XRP = 0.0; TAO = 0.0 }

    try {
        $Ids = "bitcoin,ethereum,solana,ondo-finance,hedera-hashgraph,ripple,bittensor"
        $Uri = "https://api.coingecko.com/api/v3/simple/price?ids=$Ids&vs_currencies=usd"
        $R = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 15

        $Prices.BTC  = [math]::Round([double]$R.bitcoin.usd,          2)
        $Prices.ETH  = [math]::Round([double]$R.ethereum.usd,         2)
        $Prices.SOL  = [math]::Round([double]$R.solana.usd,           2)
        $Prices.ONDO = [math]::Round([double]$R.'ondo-finance'.usd,   4)
        $Prices.HBAR = [math]::Round([double]$R.'hedera-hashgraph'.usd, 4)
        $Prices.XRP  = [math]::Round([double]$R.ripple.usd,           4)
        $Prices.TAO  = [math]::Round([double]$R.bittensor.usd,        2)

        Write-Host "✅ [DATA] Precios obtenidos. BTC: $($Prices.BTC)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ [DATA] Error al extraer precios: $_" -ForegroundColor Red
    }

    # Índice Fear & Greed
    $FngValue  = "50"
    $FngStatus = "Neutral"
    try {
        $Fng       = Invoke-RestMethod -Uri "https://api.alternative.me/fng/" -Method Get -TimeoutSec 10
        $FngValue  = $Fng.data[0].value
        $FngStatus = $Fng.data[0].value_classification
    }
    catch {
        Write-Host "⚠️ [DATA] Error al extraer Fear & Greed. Usando Neutral." -ForegroundColor Yellow
    }

    return [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        BTC       = $Prices.BTC
        ETH       = $Prices.ETH
        SOL       = $Prices.SOL
        ONDO      = $Prices.ONDO
        HBAR      = $Prices.HBAR
        XRP       = $Prices.XRP
        TAO       = $Prices.TAO
        FnGValue  = $FngValue
        FnGStatus = $FngStatus
    }
}
