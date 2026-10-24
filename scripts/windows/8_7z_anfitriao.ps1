# =============================================================================
# 8_7z_anfitriao.ps1  -  referencia de PROCESSADOR no proprio anfitriao (sem VM)
#   Benchmark do 7-Zip com 1 e 2 threads, os mesmos parametros do bench7z.sh.
#   Os 2 threads ficam presos a 2 nucleos fisicos diferentes (processadores
#   logicos 0 e 2), como os 2 vCPU sem SMT das VMs.
#   Correr no MODO VMWARE (hipervisor desligado), sem nenhuma VM ligada,
#   ligado a corrente, 10 min depois do arranque.
# Uso (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\8_7z_anfitriao.ps1 -SevenZip "C:\Program Files\7-Zip\7z.exe"
# Gera a pasta resultados_7z_anfitriao_<data>\ (cpu7z_t1_NN.txt, cpu7z_t2_NN.txt)
# =============================================================================
param(
  [Parameter(Mandatory=$true)][string]$SevenZip,
  [int]$N = 10,
  [string]$Tag = "anfitriao"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $SevenZip)) { Write-Host "7z.exe nao encontrado em $SevenZip" -ForegroundColor Red; exit 1 }

# os processos filhos herdam a afinidade: 0x5 = processadores logicos 0 e 2
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0x5

$out = "resultados_7z_${Tag}_$(Get-Date -Format yyyyMMdd_HHmm)"
New-Item -ItemType Directory -Force -Path $out | Out-Null
& {
  "== etiqueta: $Tag   data: $(Get-Date -Format s)   N=$N   (7-Zip b -md22, 1 e 2 threads, afinidade 0x5)"
  "== hipervisor presente: $((Get-CimInstance Win32_ComputerSystem).HypervisorPresent)"
  "== CPU"; Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | Format-List
  "== 7-Zip"; & $SevenZip | Select-Object -First 3
  "== energia"; powercfg /getactivescheme
} *> "$out\ambiente.txt"

Write-Host ">> Aquecimento (descartado)..." -ForegroundColor Cyan
& $SevenZip b -md22 -mmt1 | Out-Null

for ($i = 1; $i -le $N; $i++) {
  $nn = '{0:D2}' -f $i
  Write-Host ">> Repeticao $i/$N" -ForegroundColor Cyan
  Start-Sleep -Seconds 5; & $SevenZip b -md22 -mmt1 | Out-File -Encoding ascii "$out\cpu7z_t1_$nn.txt"
  Start-Sleep -Seconds 5; & $SevenZip b -md22 -mmt2 | Out-File -Encoding ascii "$out\cpu7z_t2_$nn.txt"
}
"fim: $(Get-Date -Format s)" | Add-Content "$out\ambiente.txt"
Write-Host "Concluido -> $out" -ForegroundColor Green
