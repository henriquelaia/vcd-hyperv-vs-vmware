# Hyper-V vs. VMware: Overhead da Virtualização

Materiais do 1.º Projeto Laboratorial de **Virtualização e Centros de Dados** (Departamento de Informática, Universidade da Beira Interior): comparação de desempenho entre um hipervisor nativo (Microsoft Hyper-V, Tipo 1) e um hipervisor baseado em anfitrião (VMware Workstation 17.6, Tipo 2), no mesmo equipamento, com convidados Ubuntu Server 26.04.

**Autores:** Henrique Laia (M16491) · Alexandre Santos · Daniel Basílio

## Conteúdo

| Caminho | Descrição |
|---|---|
| [`relatorio/`](relatorio) | relatório (formato IEEE conferência): `.pdf` e fonte `.tex` |
| [`COMANDOS.md`](COMANDOS.md) | **Todos os comandos usados**, passo a passo, para replicar os testes |
| [`scripts/ubuntu/`](scripts/ubuntu) | `bench.sh` (CPU, memória, disco), `bench7z.sh` (CPU com 7-Zip), `rede.sh` (rede TCP e ping), `rede_udp.sh` (rede UDP) e `parse_resultados.py` (estatística) |
| [`scripts/windows/`](scripts/windows) | scripts PowerShell para preparar, mudar e verificar o modo do anfitrião |
| [`resultados/resultados_vcd.xlsx`](resultados/resultados_vcd.xlsx) | resultados completos, com médias, desvios, IC95, Δ% e testes t em fórmulas |
| [`resultados/csv/`](resultados/csv) | `corridas.csv`, `resumo.csv` e `comparacao.csv` |
| [`resultados/dados_brutos/`](resultados/dados_brutos) | saídas originais do sysbench, fio, iperf3 e ping (10 repetições por teste) |
| [`resultados/configuracao/`](resultados/configuracao) | estado do anfitrião e das VMs em cada modo |

## Testes em falta: referência do anfitrião (portátil i5-9300H)

No portátil onde estão as VMs (Windows), descarregar o repositório:
```powershell
git clone https://github.com/henriquelaia/vcd-hyperv-vs-vmware.git
cd vcd-hyperv-vs-vmware\scripts\windows
```
Instalar: [7-Zip](https://www.7-zip.org), [fio para Windows](https://github.com/axboe/fio/releases) e [iperf3 para Windows](https://iperf.fr/iperf-download.php).

1. **Modo VMware** (`3_modo_vmware.ps1`, reiniciar, esperar 10 min), **sem VMs ligadas**:
   `8_7z_anfitriao.ps1` → `7_fio_anfitriao.ps1` → `9_rede_loopback.ps1`.
2. Ainda no modo VMware, na VM VMware: `./bench7z.sh vmware`. Opcionalmente, o teste `vmxnet3` (secção 12 do `COMANDOS.md`).
3. **Modo Hyper-V** (`2_modo_hyperv.ps1`, reiniciar), na VM Hyper-V: `./bench7z.sh hyperv`.
4. Copiar as pastas `resultados_*` para `resultados/dados_brutos/` e fazer *commit*.

Detalhes e justificação na secção 11 do [`COMANDOS.md`](COMANDOS.md#11-referência-o-anfitrião-sem-virtualização).

## Replicação rápida

```bash
# no convidado Ubuntu
./scripts/ubuntu/bench.sh hyperv     # ou vmware  (~40 min)
./scripts/ubuntu/rede.sh hyperv <IP do anfitrião>
./scripts/ubuntu/rede_udp.sh hyperv <IP do anfitrião>
python3 scripts/ubuntu/parse_resultados.py resultados_*
```
Os modos do anfitrião (hipervisor ligado/desligado, verificação de `Monitor Mode: CPL0`) estão descritos em [`COMANDOS.md`](COMANDOS.md#2-anfitrião-windows--powershell-como-administrador). A referência (o anfitrião sem virtualização: `7z`, `fio` e `iperf3` em *loopback* no Windows, mais `bench7z.sh` nas VMs) está na secção 11 do mesmo ficheiro.
