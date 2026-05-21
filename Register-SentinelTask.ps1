# Register-SentinelTask.ps1
# Registra el watchdog como tarea de Windows que arranca al iniciar sesion.
# Ejecutar UNA VEZ como Administrador.

$TaskName    = "SentinelReturns-Listener"
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$WatchdogPath = Join-Path $ScriptDir "Sentinel_Watchdog.ps1"

# Eliminar tarea previa si existe
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$WatchdogPath`""

# Trigger: al iniciar sesion del usuario actual
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName  $TaskName `
    -Action    $Action `
    -Trigger   $Trigger `
    -Settings  $Settings `
    -RunLevel  Highest `
    -Description "Sentinel Returns 2.0 — Listener Telegram 24/7" | Out-Null

Write-Host "Tarea '$TaskName' registrada correctamente." -ForegroundColor Green
Write-Host "Se activara automaticamente al iniciar sesion."
Write-Host ""
Write-Host "Para arrancarla ahora sin reiniciar:"
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
