# =============================================================================
# 6_servidor_rede.ps1  -  lado do ANFITRIAO para os testes de rede (Administrador)
#   - abre a firewall do Windows para o iperf3 (porta 5201) e para o ping
#   - mostra o IP que a VM deve usar
#   - arranca o servidor iperf3 (deixar esta janela aberta durante o rede.sh)
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\6_servidor_rede.ps1 -Iperf "C:\iperf3\iperf3.exe"
# Parar o servidor no fim: Ctrl+C
# =============================================================================
param([Parameter(Mandatory=$true)][string]$Iperf)

if (-not (Test-Path $Iperf)) { Write-Host "iperf3.exe nao encontrado em $Iperf (descarregar o iperf3 para Windows e indicar o caminho em -Iperf)" -ForegroundColor Red; exit 1 }

Write-Host "`n[1/3] Regras de firewall (VCD-iperf3, VCD-ping)" -ForegroundColor Cyan
if (-not (Get-NetFirewallRule -DisplayName "VCD-iperf3-TCP" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName "VCD-iperf3-TCP" -Direction Inbound -Protocol TCP -LocalPort 5201 -Action Allow -Profile Any | Out-Null
  New-NetFirewallRule -DisplayName "VCD-iperf3-UDP" -Direction Inbound -Protocol UDP -LocalPort 5201 -Action Allow -Profile Any | Out-Null
  New-NetFirewallRule -DisplayName "VCD-ping" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -Action Allow -Profile Any | Out-Null
}
Get-NetFirewallRule -DisplayName "VCD-*" | Select-Object DisplayName,Enabled | Format-Table -AutoSize

Write-Host "[2/3] IP a usar na VM:" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.InterfaceAlias -match "Default Switch|VMnet8|VMnet1" } |
  Select-Object InterfaceAlias,IPAddress | Format-Table -AutoSize
Write-Host "  Hyper-V -> usar o IP de 'vEthernet (Default Switch)'"
Write-Host "  VMware  -> usar o IP de 'VMware Network Adapter VMnet8' (VM em modo NAT)"

Write-Host "`n[3/3] Servidor iperf3 a correr. NAO feches esta janela ate o rede.sh acabar. (Ctrl+C para parar)" -ForegroundColor Green
& $Iperf -s
