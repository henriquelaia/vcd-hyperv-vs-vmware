# Hyper-V vs. VMware: Overhead da Virtualização

Materiais do 1.º Projeto Laboratorial de **Virtualização e Centros de Dados** (Departamento de Informática, Universidade da Beira Interior): comparação de desempenho entre um hipervisor nativo (Microsoft Hyper-V, Tipo 1) e um hipervisor baseado em anfitrião (VMware Workstation 17.6, Tipo 2), no mesmo equipamento, com convidados Ubuntu Server 26.04.

**Autores:** Henrique Laia (M16491) · Alexandre Santos · Daniel Basílio

## Conteúdo

| Caminho | Descrição |
|---|---|
| [`relatorio/`](relatorio) | relatório (formato IEEE conferência): `.pdf` e fonte `.tex` |
| [`COMANDOS.md`](COMANDOS.md) | **Todos os comandos usados**, passo a passo, para replicar os testes |
| [`scripts/ubuntu/`](scripts/ubuntu) | `bench.sh` (CPU, memória, disco), `nativo_pen.sh` (referência no Ubuntu nativo, live USB), `rede.sh` (rede TCP e ping), `rede_udp.sh` (rede UDP) e `parse_resultados.py` (estatística) |
| [`scripts/windows/`](scripts/windows) | scripts PowerShell para preparar, mudar e verificar o modo do anfitrião, e `7_fio_anfitriao.ps1` / `9_rede_loopback.ps1` (referência) |
| [`resultados/resultados_vcd.xlsx`](resultados/resultados_vcd.xlsx) | resultados completos, com médias, desvios, IC95, Δ% e testes t em fórmulas |
| [`resultados/csv/`](resultados/csv) | `corridas.csv`, `resumo.csv` e `comparacao.csv` |
| [`resultados/dados_brutos/`](resultados/dados_brutos) | saídas originais do sysbench, fio, iperf3 e ping (10 repetições por teste) |
| [`resultados/configuracao/`](resultados/configuracao) | estado do anfitrião e das VMs em cada modo |

## Sistemas de referência (sem virtualização)

Todos os testes de referência estão feitos (secção 11 do [`COMANDOS.md`](COMANDOS.md#11-referência-o-sistema-sem-virtualização)):

| Subsistema | Referência | Pasta em `resultados/dados_brutos/` |
|---|---|---|
| CPU e memória | Ubuntu 26.04.1 nativo (*live* USB), 2,4 GHz sem turbo, `sysbench` | `resultados_nativo_semturbo_20261024_2151` |
| (registo) | Ubuntu nativo com turbo (≈4 GHz) | `resultados_nativo_turbo_20261024_2041` |
| Disco | Windows anfitrião, hipervisor desligado, `fio` `windowsaio` | `resultados_anfitriao_20261024_2043` |
| Rede | Windows anfitrião, `iperf3` em *loopback* | `resultados_rede_anfitriao_20261024_2109` |

O anfitrião Windows corre a ≈2,35 GHz sem turbo; por isso, a referência nativa usada é a sem turbo. O *overhead* de cada hipervisor face ao nativo está na folha **Overhead nativo** do [`resultados_vcd.xlsx`](resultados/resultados_vcd.xlsx) e na Secção V-E do relatório.

## Replicação rápida

```bash
# no convidado Ubuntu
./scripts/ubuntu/bench.sh hyperv     # ou vmware  (~40 min)
./scripts/ubuntu/rede.sh hyperv <IP do anfitrião>
./scripts/ubuntu/rede_udp.sh hyperv <IP do anfitrião>
python3 scripts/ubuntu/parse_resultados.py resultados_*
```
Os modos do anfitrião (hipervisor ligado/desligado, verificação de `Monitor Mode: CPL0`) estão descritos em [`COMANDOS.md`](COMANDOS.md#2-anfitrião-windows--powershell-como-administrador). A referência (Ubuntu nativo em *live* USB para CPU e memória; `fio` e `iperf3` em *loopback* no Windows para disco e rede) está na secção 11 do mesmo ficheiro.
