# =============================================================================
# 5_repor_tudo.ps1  -  no FIM do trabalho, repoe o PC como estava (Administrador)
# Uso:  powershell -ExecutionPolicy Bypass -File .\5_repor_tudo.ps1
# =============================================================================
$st = @{}
if (Test-Path estado_original.txt) {
  Get-Content estado_original.txt | ForEach-Object { $k,$v = $_ -split '=',2; $st[$k] = $v }
}
bcdedit /set hypervisorlaunchtype auto
bcdedit /deletevalue hypervisorschedulertype 2>$null | Out-Null
$k = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if ($st["memory_integrity_enabled"] -eq "1") { Set-ItemProperty -Path $k -Name Enabled -Value 1 -Type DWord; Write-Host "Integridade de Memoria reposta: LIGADA" }
if ($st["hyperv_dir"]) { Remove-MpPreference -ExclusionPath $st["hyperv_dir"] }
if ($st["vmware_dir"]) { Remove-MpPreference -ExclusionPath $st["vmware_dir"] }
Get-NetFirewallRule -DisplayName "VCD-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
powercfg /setactive SCHEME_BALANCED
powercfg /change standby-timeout-ac 30
Write-Host "Reposto. Reinicia o PC para aplicar." -ForegroundColor Green
