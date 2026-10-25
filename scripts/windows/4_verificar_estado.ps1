# =============================================================================
# 4_verificar_estado.ps1  -  confirma o modo antes de cada bateria de testes
# Uso:  powershell -ExecutionPolicy Bypass -File .\4_verificar_estado.ps1 [-VmwareDir "C:\...\pasta VM"]
#   Para o VMware: correr depois de arrancar a máquina virtual (o vmware.log é criado ao arrancar).
# =============================================================================
param([string]$VmwareDir = "")

$hv = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
$dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
$ev = Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Hyper-V-Hypervisor';Id=2} -MaxEvents 1 -ErrorAction SilentlyContinue
$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

Write-Host "`n==================== ESTADO DO ANFITRIÃO ====================" -ForegroundColor Cyan
Write-Host ("Último arranque           : {0}" -f $boot)
Write-Host ("Hipervisor presente       : {0}" -f $hv)
Write-Host ("bcdedit                   : {0}" -f ((bcdedit /enum '{current}' | Select-String 'hypervisor') -join ' | '))
Write-Host ("VBS (0=off 1=cfg 2=ativo) : {0}" -f $dg.VirtualizationBasedSecurityStatus)
Write-Host ("Serviços VBS a correr     : {0}" -f ($dg.SecurityServicesRunning -join ','))
if ($ev -and $ev.TimeCreated -gt $boot) {
  Write-Host ("Escalonador Hyper-V       : {0}" -f $ev.Message)
} else {
  Write-Host  "Escalonador Hyper-V       : (sem evento neste arranque -> hipervisor não carregou)"
}
Write-Host ("Plano de energia          : {0}" -f (powercfg /getactivescheme))

if ($VmwareDir -ne "") {
  Write-Host "`n------------------------ VMWARE ------------------------" -ForegroundColor Cyan
  $log = Join-Path $VmwareDir "vmware.log"
  if (Test-Path $log) {
    Select-String -Path $log -Pattern "Monitor Mode" | Select-Object -First 3 | ForEach-Object { $_.Line }
  } else { Write-Host "vmware.log não encontrado - arranca a VM primeiro." -ForegroundColor Yellow }
}

Write-Host "`n------------------------ VEREDICTO ------------------------" -ForegroundColor Cyan
if ($hv) {
  Write-Host "MODO HYPER-V: pronto para testar a VM Hyper-V." -ForegroundColor Green
  Write-Host "NÃO testar o VMware neste modo (correria sobre o Hyper-V, modo ULM)." -ForegroundColor Red
} else {
  Write-Host "MODO VMWARE: pronto para testar a VM VMware." -ForegroundColor Green
  Write-Host "Confirma acima 'Monitor Mode: CPL0'. Se aparecer ULM, algo ainda carrega o hipervisor." -ForegroundColor Yellow
}
