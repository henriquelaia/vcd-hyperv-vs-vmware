# =============================================================================
# 3_modo_vmware.ps1  -  prepara o PC para os testes do VMware (Administrador)
#   - desliga o hipervisor do Windows (o Hyper-V deixa de carregar no arranque)
#   - desliga a Integridade de Memoria (HVCI), que tambem precisa do hipervisor
# O estado original fica em estado_original.txt (criado pelo script 1) e e
# reposto pelo script 5_repor_tudo.ps1.
# Uso:  powershell -ExecutionPolicy Bypass -File .\3_modo_vmware.ps1
# =============================================================================
bcdedit /set hypervisorlaunchtype off
$k = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
Set-ItemProperty -Path $k -Name Enabled -Value 0 -Type DWord
Write-Host "`nHipervisor: DESLIGADO  |  Integridade de Memoria: DESLIGADA" -ForegroundColor Green
Write-Host "As VMs do Hyper-V NAO arrancam neste modo (normal)." -ForegroundColor Yellow
Write-Host "E PRECISO REINICIAR. Depois do reinicio corre 4_verificar_estado.ps1" -ForegroundColor Yellow
$r = Read-Host "Reiniciar agora? (s/n)"
if ($r -eq "s") { Restart-Computer -Force }
