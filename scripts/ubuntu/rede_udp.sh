#!/usr/bin/env bash
# =============================================================================
# rede_udp.sh — testes de rede UDP convidado -> anfitrião (iperf3): jitter e perda
# Complementa o rede.sh (TCP + ping). Metodologia alinhada com Louro (2018).
# Correr DENTRO da VM Ubuntu, com o servidor iperf3 a correr no Windows
# (6_servidor_rede.ps1).
#
#   uso:   chmod +x rede_udp.sh
#          ./rede_udp.sh hyperv IP_DO_ANFITRIAO
#          ./rede_udp.sh vmware IP_DO_ANFITRIAO
#
#   Testes (10 repetições, 10 s cada, com aquecimento):
#     net_udp_1m     -> iperf3 -u -c H            (débito predefinido de 1 Mbit/s, como no Louro)
#     net_udp_100m   -> iperf3 -u -c H -b 100M    (carga moderada)
#     net_udp_1g     -> iperf3 -u -c H -b 1G      (carga elevada: perda)
#   Métricas: jitter (ms), perda (%), débito recebido (Mbit/s)
#   duração aproximada: ~7 minutos. No fim cria resultados_rede_udp_<etiqueta>_<data>.tar.gz
# =============================================================================
set -euo pipefail

TAG=${1:?"uso: ./rede_udp.sh hyperv|vmware IP_DO_ANFITRIAO"}
HOST=${2:?"falta o IP do anfitrião (ver ipconfig no Windows)"}
N=${N:-10}
T=${T:-10}
OUT="resultados_rede_udp_${TAG}_$(date +%Y%m%d_%H%M)"
mkdir -p "$OUT"

command -v iperf3 >/dev/null || { sudo apt-get update -qq; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iperf3 >/dev/null; }

IFACE=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}' || true)
{
  echo "== etiqueta: $TAG   anfitriao: $HOST   N=$N   T=${T}s   data: $(date -Is)   (UDP)"
  echo "== driver ($IFACE)"; readlink -f "/sys/class/net/$IFACE/device/driver" 2>/dev/null || true
  echo "== MTU";             cat "/sys/class/net/$IFACE/mtu" 2>/dev/null || true
  echo "== versoes";         iperf3 --version | head -1
} > "$OUT/ambiente_rede.txt" 2>&1

if ! iperf3 -c "$HOST" -u -t 2 >/dev/null 2>&1; then
  echo "!! O iperf3 UDP não liga. Confirma 'iperf3 -s' no Windows e a regra de firewall UDP 5201."
  exit 1
fi

echo ">> Aquecimento (descartado)…"
iperf3 -c "$HOST" -u -b 100M -t 3 >/dev/null

for i in $(seq -w 1 "$N"); do
  echo ">> Repetição $i/$N"
  iperf3 -c "$HOST" -u -t "$T" -J          > "$OUT/net_udp_1m_$i.json";   sleep 2
  iperf3 -c "$HOST" -u -b 100M -t "$T" -J  > "$OUT/net_udp_100m_$i.json"; sleep 2
  iperf3 -c "$HOST" -u -b 1G -t "$T" -J    > "$OUT/net_udp_1g_$i.json";   sleep 2
done

tar czf "$OUT.tar.gz" "$OUT"
echo ">> Concluído. Ficheiro para trazer para o Windows:  $(pwd)/$OUT.tar.gz"
