#!/usr/bin/env bash
# =============================================================================
# nativo_pen.sh — referência Linux "sem virtualização": Ubuntu 26.04 em live USB,
# diretamente no hardware do portátil das VMs.
# Corre o bench.sh (CPU e memória, sem disco) e o bench7z.sh, com os 2 threads
# presos a 2 núcleos físicos diferentes, como os 2 vCPU sem SMT das VMs.
#
#   uso:   bash nativo_pen.sh 2501   # 2501 = versão do 7-Zip instalada no Windows (25.01)
#
#   precisa de Internet (instala o sysbench e descarrega o 7-Zip para Linux).
#   duração aproximada: ~40 minutos. Ligado à corrente e sem mexer no PC.
#   ATENÇÃO: no live USB tudo fica em RAM — copiar os .tar.gz antes de desligar!
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

V7Z=${1:?"uso: ./nativo_pen.sh <versão do 7-Zip do Windows, ex.: 2501>"}

# impede que o Ubuntu suspenda ou bloqueie o ecrã a meio dos testes
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null || true
gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true

# um processador lógico por núcleo físico, os 2 primeiros (equivalente à afinidade 0x5 no Windows)
CPUS=$(lscpu -p=CPU,CORE | grep -v '^#' | sort -t, -k2,2n -k1,1n \
       | awk -F, '!visto[$2]++ {print $1}' | head -2 | paste -sd, -)
echo ">> Testes presos aos processadores lógicos: $CPUS"
lscpu -e > info_cpu_nativo.txt

echo ">> A descarregar o 7-Zip $V7Z para Linux…"
wget -q "https://www.7-zip.org/a/7z${V7Z}-linux-x64.tar.xz" -O /tmp/7z.tar.xz
mkdir -p ~/7z && tar xf /tmp/7z.tar.xz -C ~/7z

chmod +x bench.sh bench7z.sh
SKIP_FIO=1 taskset -c "$CPUS" ./bench.sh nativo
taskset -c "$CPUS" ./bench7z.sh nativo

echo
echo ">> FEITO. Copiar estes ficheiros para fora da pen ANTES de desligar:"
ls -1 "$PWD"/resultados_*nativo_*.tar.gz "$PWD"/info_cpu_nativo.txt
