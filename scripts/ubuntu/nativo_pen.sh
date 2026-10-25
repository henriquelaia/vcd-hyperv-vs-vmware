#!/usr/bin/env bash
# =============================================================================
# nativo_pen.sh — referência sem virtualização: Ubuntu 26.04 em live USB,
# no mesmo portátil das máquinas virtuais.
# Corre o bench.sh (CPU e memória, sem disco) com 2 threads fixados em
# 2 núcleos físicos diferentes, como os 2 vCPU das máquinas virtuais.
#
#   uso:   sudo bash nativo_pen.sh
#
#   antes de correr (COMANDOS.md, secção 11.2):
#     1) modo de energia "Desempenho" (Definições > Energia)
#     2) turbo desligado, para ficar perto da frequência do Windows (~2,35 GHz):
#          echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
#          lscpu -e      # MAXMHZ tem de ser 2400
#
#   precisa de Internet (instala o sysbench). Duração: cerca de 25 minutos.
#   No live USB os resultados ficam em RAM: copiá-los antes de desligar.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

# impede a suspensão e o bloqueio do ecrã durante os testes
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null || true
gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true

# escolhe 2 processadores lógicos em núcleos físicos diferentes
CPUS=$(lscpu -p=CPU,CORE | grep -v '^#' | sort -t, -k2,2n -k1,1n \
       | awk -F, '!visto[$2]++ {print $1}' | head -2 | paste -sd, -)
echo ">> Testes presos aos processadores lógicos: $CPUS"
lscpu -e > info_cpu_nativo.txt
echo "no_turbo: $(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo n/a)" >> info_cpu_nativo.txt

# perfil de energia em desempenho, se o powerprofilesctl existir
powerprofilesctl set performance 2>/dev/null || echo "!! powerprofilesctl indisponível: confirmar o modo Desempenho nas Definições"
echo "perfil de energia: $(powerprofilesctl get 2>/dev/null || echo n/a)" >> info_cpu_nativo.txt

chmod +x bench.sh
SKIP_FIO=1 taskset -c "$CPUS" ./bench.sh nativo

echo
echo ">> FEITO. Copiar estes ficheiros para fora da pen ANTES de desligar:"
ls -1d "$PWD"/resultados_nativo_* "$PWD"/info_cpu_nativo.txt
