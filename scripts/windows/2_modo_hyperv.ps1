# =============================================================================
# 2_modo_hyperv.ps1  -  prepara o PC para os testes do Hyper-V (Administrador)
#   -Scheduler root  (predefinido do Windows 11)  -> teste principal
#   -Scheduler core  -> experiencia extra do escalonador (ONLY_CPU=1 ./bench.sh hypervcorenosmt)
# Uso:  powershell -ExecutionPolicy Bypass -File .\2_modo_hyperv.ps1 -Scheduler root
# =============================================================================
param([ValidateSet("root","core","classic")][string]$Scheduler = "root")

bcdedit /set hypervisorlaunchtype auto
if ($Scheduler -eq "root") {
  bcdedit /deletevalue hypervisorschedulertype 2>$null | Out-Null   # volta ao predefinido (root)
} else {
  bcdedit /set hypervisorschedulertype $Scheduler
}
Write-Host "`nHipervisor: LIGADO  |  escalonador pedido: $Scheduler" -ForegroundColor Green
Write-Host "E PRECISO REINICIAR. Depois do reinicio corre 4_verificar_estado.ps1" -ForegroundColor Yellow
$r = Read-Host "Reiniciar agora? (s/n)"
if ($r -eq "s") { Restart-Computer -Force }
