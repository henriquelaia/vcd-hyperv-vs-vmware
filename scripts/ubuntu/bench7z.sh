#!/usr/bin/env bash
# =============================================================================
# bench7z.sh — processador com o benchmark do 7-Zip (mesma ferramenta no
# anfitrião Windows e nas VMs, para quantificar o overhead face ao anfitrião).
# Correr DENTRO da VM Ubuntu (Hyper-V ou VMware), só com essa VM ligada.
#
#   uso:   chmod +x bench7z.sh
#          ./bench7z.sh hyperv          # na VM Hyper-V  (anfitrião em modo Hyper-V)
#          ./bench7z.sh vmware          # na VM VMware   (anfitrião em modo VMware, CPL0)
#
#   O 7-Zip tem de ser a MESMA versão do Windows (7zz oficial de 7-zip.org):
#          wget https://www.7-zip.org/a/7z2409-linux-x64.tar.xz   # ajustar à versão do Windows
#          mkdir -p ~/7z && tar xf 7z2409-linux-x64.tar.xz -C ~/7z
#   variáveis opcionais:  Z=~/7z/7zz (executável)   N=10 (repetições)
#   duração aproximada: ~10 minutos. No fim cria resultados_7z_<etiqueta>_<data>/
# =============================================================================
set -euo pipefail

TAG=${1:?"uso: ./bench7z.sh hyperv|vmware"}
Z=${Z:-$HOME/7z/7zz}
N=${N:-10}
command -v "$Z" >/dev/null || { echo "!! 7zz não encontrado em $Z (ver o cabeçalho deste script)"; exit 1; }
OUT="resultados_7z_${TAG}_$(date +%Y%m%d_%H%M)"
mkdir -p "$OUT"

# dicionário fixo de 4 MiB (-md22): sem isto, o 7-Zip escolhe o tamanho em função
# da RAM, que é diferente no anfitrião (16 GB) e nas VMs (4 GB)
B="b -md22"
{
  echo "== etiqueta: $TAG   data: $(date -Is)   N=$N   (7-Zip $B, 1 e 2 threads)"
  echo "== uname";         uname -a
  echo "== virtualizacao"; systemd-detect-virt || true
  echo "== lscpu";         lscpu
  echo "== 7-Zip";         "$Z" 2>&1 | head -3 || true
} > "$OUT/ambiente.txt" 2>&1

echo ">> Aquecimento (descartado)…"
"$Z" $B -mmt1 >/dev/null

for i in $(seq -w 1 "$N"); do
  echo ">> Repetição $i/$N"
  sleep 5; "$Z" $B -mmt1 > "$OUT/cpu7z_t1_$i.txt"
  sleep 5; "$Z" $B -mmt2 > "$OUT/cpu7z_t2_$i.txt"
done

echo "fim: $(date -Is)" >> "$OUT/ambiente.txt"
tar czf "$OUT.tar.gz" "$OUT"
echo ">> Concluído. Ficheiro para trazer para o Windows:  $(pwd)/$OUT.tar.gz"
