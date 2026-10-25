# =============================================================================
# 1_preparar_anfitriao.ps1  -  corre uma vez, como Administrador
#   - ativa o plano de energia "Elevado desempenho"
#   - exclui as pastas das VMs da análise em tempo real do Microsoft Defender
#   - guarda o estado atual em estado_original.txt
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\1_preparar_anfitriao.ps1 `
#       -HyperVDir "C:\ProgramData\Microsoft\Windows\Virtual Hard Disks" `
#       -VmwareDir "C:\Users\Admin\Documents\Virtual Machines\Ubuntu"
# =============================================================================
param(
  [Parameter(Mandatory=$true)][string]$HyperVDir,
  [Parameter(Mandatory=$true)][string]$VmwareDir
)
$ErrorActionPreference = "Continue"

Write-Host "`n[1/3] Plano de energia -> Elevado desempenho" -ForegroundColor Cyan
powercfg /setactive SCHEME_MIN
powercfg /getactivescheme
# nunca suspender/hibernar ligado à corrente (os testes demoram cerca de 40 min)
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

Write-Host "`nBitLocker (se Protection On: ter a chave de recuperação à mão antes de mudar o bcdedit)" -ForegroundColor Cyan
manage-bde -status C: | Select-String "Protection Status|Estado da Prote"

Write-Host "`n[2/3] Exclusões do Microsoft Defender" -ForegroundColor Cyan
Add-MpPreference -ExclusionPath $HyperVDir
Add-MpPreference -ExclusionPath $VmwareDir
(Get-MpPreference).ExclusionPath

Write-Host "`n[3/3] Estado atual guardado em estado_original.txt" -ForegroundColor Cyan
$hvci = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -ErrorAction SilentlyContinue).Enabled
@(
  "data=$(Get-Date -Format s)",
  "hypervisorlaunchtype=$((bcdedit /enum '{current}' | Select-String hypervisorlaunchtype) -replace '\s+',' ')",
  "memory_integrity_enabled=$hvci",
  "hyperv_dir=$HyperVDir",
  "vmware_dir=$VmwareDir"
) | Set-Content estado_original.txt
Get-Content estado_original.txt
Write-Host "`nFeito. Se for portátil: ligar à corrente e manter ligado durante TODOS os testes." -ForegroundColor Green
