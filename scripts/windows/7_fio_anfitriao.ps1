# =============================================================================
# 7_fio_anfitriao.ps1  -  referência de disco no próprio anfitrião (sem VM)
#   Corre os mesmos 6 perfis do bench.sh com o fio para Windows, no NVMe/NTFS.
#   --direct=1 no Windows abre o ficheiro sem a cache do sistema, por isso não
#   é preciso limpar a cache entre testes.
#   Correr no modo VMware (hipervisor desligado: Windows diretamente no hardware),
#   sem nenhuma VM ligada, ligado à corrente, 10 min depois do arranque.
# Uso (PowerShell como Administrador):
#   powershell -ExecutionPolicy Bypass -File .\7_fio_anfitriao.ps1 -Fio "C:\Program Files\fio\fio.exe"
# Gera a pasta resultados_anfitriao_<data>\ (fio_*_NN.json), lida pelo parse_resultados.py
# =============================================================================
param(
  [Parameter(Mandatory=$true)][string]$Fio,
  [string]$Dir = "C:\fio_teste",
  [int]$N = 10,
  [string]$Tag = "anfitriao"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Fio)) { Write-Host "fio.exe não encontrado em $Fio" -ForegroundColor Red; exit 1 }

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$out = "resultados_${Tag}_$(Get-Date -Format yyyyMMdd_HHmm)"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ff = (Join-Path $Dir "fio_teste.dat") -replace ':', '\:'   # o fio exige ':' escapado no Windows

$base = @("--ioengine=windowsaio", "--direct=1", "--thread", "--filename=$ff", "--size=4G", "--numjobs=1",
          "--time_based", "--runtime=15", "--ramp_time=3", "--group_reporting", "--output-format=json")
$tests = [ordered]@{
  "fio_randread_4k_qd1"  = @("--name=rr",    "--rw=randread",  "--bs=4k", "--iodepth=1")
  "fio_randwrite_4k_qd1" = @("--name=rw",    "--rw=randwrite", "--bs=4k", "--iodepth=1")
  "fio_randrw_4k_qd1"    = @("--name=rrw",   "--rw=randrw", "--rwmixread=50", "--bs=4k", "--iodepth=1")
  "fio_randrw_4k_qd32"   = @("--name=rrw32", "--rw=randrw", "--rwmixread=50", "--bs=4k", "--iodepth=32")
  "fio_seqread_1m_qd16"  = @("--name=sr",    "--rw=read",  "--bs=1M", "--iodepth=16")
  "fio_seqwrite_1m_qd16" = @("--name=sw",    "--rw=write", "--bs=1M", "--iodepth=16")
}

& {
  "== etiqueta: $Tag   data: $(Get-Date -Format s)   N=$N   (fio 15s+3s, windowsaio, direct=1)"
  "== hipervisor presente: $((Get-CimInstance Win32_ComputerSystem).HypervisorPresent)"
  "== fio"; & $Fio --version
  "== discos"; Get-PhysicalDisk | Select-Object FriendlyName,MediaType,BusType,Size | Format-Table -AutoSize
  "== volume"; Get-Volume -DriveLetter ($Dir.Substring(0,1)) | Format-Table -AutoSize
  "== energia"; powercfg /getactivescheme
} *> "$out\ambiente.txt"

Write-Host ">> A preparar o ficheiro de teste (4 GiB)..." -ForegroundColor Cyan
& $Fio --name=layout "--filename=$ff" --size=4G --rw=write --bs=1M --direct=1 --ioengine=windowsaio --thread --iodepth=16 | Out-Null

Write-Host ">> Corrida de aquecimento (descartada)..." -ForegroundColor Cyan
foreach ($t in $tests.Keys) { & $Fio @base @($tests[$t]) | Out-Null }

for ($i = 1; $i -le $N; $i++) {
  Write-Host ">> Repetição $i/$N" -ForegroundColor Cyan
  foreach ($t in $tests.Keys) {
    Start-Sleep -Seconds 5
    & $Fio @base @($tests[$t]) "--output=$out\$($t)_$('{0:D2}' -f $i).json" | Out-Null
  }
}
Remove-Item (Join-Path $Dir "fio_teste.dat") -ErrorAction SilentlyContinue
"fim: $(Get-Date -Format s)" | Add-Content "$out\ambiente.txt"
Write-Host "Concluído -> $out" -ForegroundColor Green
