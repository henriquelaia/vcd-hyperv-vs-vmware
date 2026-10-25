# =============================================================================
# 9_rede_loopback.ps1  -  referência de rede no próprio anfitrião (sem VM)
#   Sem virtualização não existe o caminho convidado<->anfitrião; mede-se o
#   loopback do Windows (127.0.0.1) como limite superior da pilha de rede,
#   com os mesmos testes TCP do rede.sh (10 repetições, 10 s, aquecimento).
#   Correr no modo VMware (hipervisor desligado), sem nenhuma VM ligada.
# Uso (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\9_rede_loopback.ps1 -Iperf "C:\iperf3\iperf3.exe"
# Gera a pasta resultados_rede_anfitriao_<data>\ (net_tcp_*_NN.json)
# =============================================================================
param(
  [Parameter(Mandatory=$true)][string]$Iperf,
  [int]$N = 10,
  [int]$T = 10,
  [string]$Tag = "anfitriao"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Iperf)) { Write-Host "iperf3.exe não encontrado em $Iperf" -ForegroundColor Red; exit 1 }

$out = "resultados_rede_${Tag}_$(Get-Date -Format yyyyMMdd_HHmm)"
New-Item -ItemType Directory -Force -Path $out | Out-Null
& {
  "== etiqueta: $Tag   anfitriao: 127.0.0.1 (loopback)   N=$N   T=${T}s   data: $(Get-Date -Format s)"
  "== hipervisor presente: $((Get-CimInstance Win32_ComputerSystem).HypervisorPresent)"
  "== versoes"; & $Iperf --version
} *> "$out\ambiente_rede.txt"

$srv = Start-Process -FilePath $Iperf -ArgumentList "-s" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
try {
  Write-Host ">> Aquecimento (descartado)..." -ForegroundColor Cyan
  & $Iperf -c 127.0.0.1 -t 3 | Out-Null
  for ($i = 1; $i -le $N; $i++) {
    $nn = '{0:D2}' -f $i
    Write-Host ">> Repetição $i/$N" -ForegroundColor Cyan
    & $Iperf -c 127.0.0.1 -t $T -J      | Out-File -Encoding ascii "$out\net_tcp_up_$nn.json";    Start-Sleep 2
    & $Iperf -c 127.0.0.1 -t $T -R -J   | Out-File -Encoding ascii "$out\net_tcp_down_$nn.json";  Start-Sleep 2
    & $Iperf -c 127.0.0.1 -t $T -P 4 -J | Out-File -Encoding ascii "$out\net_tcp_up_p4_$nn.json"; Start-Sleep 2
  }
} finally {
  Stop-Process -Id $srv.Id -ErrorAction SilentlyContinue
}
Write-Host "Concluído -> $out" -ForegroundColor Green
