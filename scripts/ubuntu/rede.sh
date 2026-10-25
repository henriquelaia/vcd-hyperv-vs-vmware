#!/usr/bin/env bash
# =============================================================================
# rede.sh — testes de rede convidado <-> anfitrião (iperf3 + ping)
# Corre dentro da máquina virtual Ubuntu, com o servidor iperf3 ligado no
# Windows (6_servidor_rede.ps1).
#
#   uso:   chmod +x rede.sh
#          ./rede.sh hyperv IP_DO_ANFITRIAO
#          ./rede.sh vmware IP_DO_ANFITRIAO
#
#   IP_DO_ANFITRIAO (ver no Windows com "ipconfig"):
#     Hyper-V -> adaptador "vEthernet (Default Switch)"
#     VMware  -> adaptador "VMware Network Adapter VMnet8"   (modo NAT)
#
#   variáveis opcionais: N=10 (repetições)  T=10 (segundos por teste iperf3)
#   duração: cerca de 9 minutos. No fim cria resultados_rede_<etiqueta>_<data>.tar.gz
# =============================================================================
set -euo pipefail

TAG=${1:?"uso: ./rede.sh hyperv|vmware IP_DO_ANFITRIAO"}
HOST=${2:?"falta o IP do anfitrião (ver ipconfig no Windows)"}
N=${N:-10}
T=${T:-10}
OUT="resultados_rede_${TAG}_$(date +%Y%m%d_%H%M)"
mkdir -p "$OUT"

if ! command -v iperf3 >/dev/null; then
  echo ">> A instalar iperf3…"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iperf3 >/dev/null
fi

IFACE=$(ip route | awk '/default/ {print $5; exit}')
{
  echo "== etiqueta: $TAG   anfitriao: $HOST   N=$N   T=${T}s   data: $(date -Is)"
  echo "== interfaces";   ip -br a
  echo "== rotas";        ip route
  echo "== driver ($IFACE)"; readlink -f "/sys/class/net/$IFACE/device/driver" 2>/dev/null || true
  echo "== modulos rede"; lsmod | grep -Ei 'hv_netvsc|vmxnet3|e1000' || true
  echo "== MTU";          cat "/sys/class/net/$IFACE/mtu" 2>/dev/null || true
  echo "== versoes";      iperf3 --version | head -1
} > "$OUT/ambiente_rede.txt" 2>&1

echo ">> A verificar ligação a $HOST…"
if ! ping -c 3 -W 2 "$HOST" >/dev/null 2>&1; then
  echo "!! Sem resposta ao ping. Abre a firewall do Windows (6_servidor_rede.ps1)."
  exit 1
fi
if ! iperf3 -c "$HOST" -t 2 >/dev/null 2>&1; then
  echo "!! O iperf3 não liga. Confirma que 'iperf3 -s' está a correr no Windows e a firewall (porta 5201)."
  exit 1
fi

echo ">> Aquecimento (descartado)…"
iperf3 -c "$HOST" -t 3 >/dev/null

for i in $(seq -w 1 "$N"); do
  echo ">> Repetição $i/$N"
  iperf3 -c "$HOST" -t "$T" -J      > "$OUT/net_tcp_up_$i.json";    sleep 2   # convidado -> anfitrião
  iperf3 -c "$HOST" -t "$T" -R -J   > "$OUT/net_tcp_down_$i.json";  sleep 2   # anfitrião -> convidado
  iperf3 -c "$HOST" -t "$T" -P 4 -J > "$OUT/net_tcp_up_p4_$i.json"; sleep 2   # 4 ligações paralelas
  ping -c 50 -i 0.2 -q "$HOST"      > "$OUT/net_ping_$i.txt" || true; sleep 2 # latência (RTT)
done

tar czf "$OUT.tar.gz" "$OUT"
echo ">> Concluído. Ficheiro para trazer para o Windows:  $(pwd)/$OUT.tar.gz"
