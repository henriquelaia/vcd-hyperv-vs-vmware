#!/usr/bin/env bash
# =============================================================================
# bench.sh — bateria de benchmarks para o trabalho de VCD (UBI)
# Corre dentro da máquina virtual Ubuntu ou no Ubuntu nativo (live USB).
#
#   uso:   chmod +x bench.sh
#          ./bench.sh hyperv          # na VM Hyper-V
#          ./bench.sh vmware          # na VM VMware
#          ./bench.sh nativo          # Ubuntu diretamente no hardware (referência)
#
#   variáveis opcionais:
#          N=10            número de repetições medidas (por omissão 10)
#          FIO_DIR=/mnt/x  pasta onde o fio cria o ficheiro de teste
#                          (no live USB, / está em RAM)
#          SKIP_FIO=1      não corre os testes de disco
#          ONLY_CPU=1      só corre os testes de CPU
#
#   duração: cerca de 40 minutos.
#   No fim é criada a pasta  resultados_<etiqueta>_<data>/  e o respetivo .tar.gz
# =============================================================================
set -euo pipefail

TAG=${1:?"uso: ./bench.sh hyperv|vmware|nativo"}
T_SYS=10     # segundos por teste sysbench
T_FIO=15     # segundos por teste fio
T_RAMP=3     # segundos de arranque do fio (não medidos)
N=${N:-10}
FIO_DIR=${FIO_DIR:-$HOME/fio_teste}
OUT="resultados_${TAG}_$(date +%Y%m%d_%H%M)"
THREADS=2
SKIP_FIO=${SKIP_FIO:-0}
ONLY_CPU=${ONLY_CPU:-0}
[ "$ONLY_CPU" = 1 ] && SKIP_FIO=1
mkdir -p "$OUT" "$FIO_DIR"

# pede a password do sudo uma vez e mantém-na válida durante todo o teste
sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &

echo ">> A instalar ferramentas (sysbench, fio)…"
sudo apt-get update -qq
if ! sudo apt-get install -y -qq sysbench fio >/dev/null 2>&1; then
  echo ">> A ativar o repositório 'universe' e a tentar de novo…"
  sudo add-apt-repository -y universe >/dev/null && sudo apt-get update -qq
  sudo apt-get install -y -qq sysbench fio >/dev/null
fi

# ---------------------------------------------------------------- ambiente ---
echo ">> A recolher informação do ambiente…"
{
  echo "== etiqueta: $TAG   data: $(date -Is)   N=$N   (sysbench ${T_SYS}s, fio ${T_FIO}s+${T_RAMP}s)"
  echo "== uname";            uname -a
  echo "== os-release";       cat /etc/os-release
  echo "== virtualizacao";    systemd-detect-virt || true
  echo "== lscpu";            lscpu
  echo "== memoria";          free -m
  echo "== discos";           lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,ROTA,MODEL
  echo "== fs do teste fio";  df -T "$FIO_DIR"
  echo "== escalonador I/O";  for f in /sys/block/*/queue/scheduler; do echo "$f: $(cat "$f")"; done
  echo "== modulos virt";     lsmod | grep -Ei 'hv_|hyperv|vmw|vmxnet|nvme|mptspi|mpt3sas' || true
  echo "== governor CPU";     cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "n/a (normal numa VM)"
  echo "== versoes";          sysbench --version; fio --version
  echo "== open-vm-tools";    dpkg -l | grep -E 'open-vm-tools|linux-cloud-tools|hyperv' || true
} > "$OUT/ambiente.txt" 2>&1

drop_caches() { sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null; sleep 3; }

# ----------------------------------------------------------------- testes ---
# formato: nome|comando
SYSBENCH_TESTS=(
  "cpu_t1|sysbench cpu --cpu-max-prime=20000 --threads=1 --time=$T_SYS run"
  "cpu_t2|sysbench cpu --cpu-max-prime=20000 --threads=$THREADS --time=$T_SYS run"
  "mem_1k_seq_w|sysbench memory --threads=$THREADS --memory-block-size=1K --memory-total-size=100G --time=$T_SYS run"
  "mem_1m_seq_w|sysbench memory --threads=$THREADS --memory-block-size=1M --memory-total-size=500G --memory-oper=write --time=$T_SYS run"
  "mem_1m_seq_r|sysbench memory --threads=$THREADS --memory-block-size=1M --memory-total-size=500G --memory-oper=read --time=$T_SYS run"
  "mem_256m_rnd_r|sysbench memory --threads=$THREADS --memory-block-size=256M --memory-total-size=500G --memory-access-mode=rnd --memory-oper=read --time=$T_SYS run"
)

if [ "$ONLY_CPU" = 1 ]; then
  SYSBENCH_TESTS=("${SYSBENCH_TESTS[@]:0:2}")
fi

FIO_FILE="$FIO_DIR/fio_teste.dat"
FIO_BASE="--ioengine=libaio --direct=1 --filename=$FIO_FILE --size=4G --numjobs=1 --time_based --runtime=$T_FIO --ramp_time=$T_RAMP --group_reporting --output-format=json"
FIO_TESTS=(
  "fio_randread_4k_qd1|--name=rr  --rw=randread  --bs=4k --iodepth=1"
  "fio_randwrite_4k_qd1|--name=rw --rw=randwrite --bs=4k --iodepth=1"
  "fio_randrw_4k_qd1|--name=rrw  --rw=randrw --rwmixread=50 --bs=4k --iodepth=1"
  "fio_randrw_4k_qd32|--name=rrw32 --rw=randrw --rwmixread=50 --bs=4k --iodepth=32"
  "fio_seqread_1m_qd16|--name=sr --rw=read  --bs=1M --iodepth=16"
  "fio_seqwrite_1m_qd16|--name=sw --rw=write --bs=1M --iodepth=16"
)

if [ "$SKIP_FIO" = 1 ]; then FIO_TESTS=(); fi
if [ "${#FIO_TESTS[@]}" -gt 0 ]; then
echo ">> A preparar ficheiro de teste do fio (4 GiB, escrito uma vez)…"
fio --name=layout --filename="$FIO_FILE" --size=4G --rw=write --bs=1M --direct=1 \
    --ioengine=libaio --iodepth=16 >/dev/null
fi

# --------------------------------------------------------------- aquecimento -
echo ">> Corrida de aquecimento (descartada)…"
for t in "${SYSBENCH_TESTS[@]}"; do eval "${t#*|}" >/dev/null; done
for t in "${FIO_TESTS[@]+"${FIO_TESTS[@]}"}"; do drop_caches; eval fio $FIO_BASE ${t#*|} >/dev/null; done

# ---------------------------------------------------------------- medições ---
# em cada repetição correm CPU, memória e disco, por esta ordem
for i in $(seq 1 "$N"); do
  echo ">> Repetição $i/$N"
  for t in "${SYSBENCH_TESTS[@]}"; do
    name=${t%%|*}; cmd=${t#*|}
    sleep 5
    eval "$cmd" > "$OUT/${name}_$(printf %02d "$i").txt"
  done
  for t in "${FIO_TESTS[@]+"${FIO_TESTS[@]}"}"; do
    name=${t%%|*}; args=${t#*|}
    drop_caches
    eval fio $FIO_BASE $args --output="$OUT/${name}_$(printf %02d "$i").json"
  done
done

rm -f "$FIO_FILE"
echo "fim: $(date -Is)" >> "$OUT/ambiente.txt"
tar czf "$OUT.tar.gz" "$OUT"
echo ">> Concluído. Ficheiro para trazer para o Windows:  $(pwd)/$OUT.tar.gz"
