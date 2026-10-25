# Hyper-V vs. VMware: Comandos de Benchmark (Replicação)

Comandos usados no trabalho **"Hyper-V vs. VMware: Overhead da Virtualização"** (Virtualização e Centros de Dados, Universidade da Beira Interior).
Todos foram executados exatamente como indicado, de forma automatizada pelos scripts [`bench.sh`](scripts/ubuntu/bench.sh), [`rede.sh`](scripts/ubuntu/rede.sh) e [`rede_udp.sh`](scripts/ubuntu/rede_udp.sh).

---

## Índice

1. [Ambiente](#1-ambiente)
2. [Anfitrião: modos de arranque](#2-anfitrião-windows--powershell-como-administrador)
3. [Convidado: preparação](#3-convidado-ubuntu--preparação)
4. [Processador](#4-processador)
5. [Memória](#5-memória)
6. [Disco](#6-disco)
7. [Rede](#7-rede)
8. [Procedimento](#8-procedimento)
9. [Execução automática com os scripts](#9-execução-automática-com-os-scripts)
10. [Processamento dos resultados](#10-processamento-dos-resultados)
11. [Referência: o sistema sem virtualização](#11-referência-o-sistema-sem-virtualização)
12. [VMware com placa paravirtualizada vmxnet3 (opcional)](#12-vmware-com-placa-paravirtualizada-vmxnet3-opcional)

---

## 1. Ambiente

| | Hyper-V (Tipo 1) | VMware Workstation (Tipo 2) |
|---|---|---|
| Anfitrião | Intel Core i5-9300H (4C/8T), 16 GB DDR4-2666, NVMe Samsung PM981 1 TB | igual |
| SO anfitrião | Windows 11 Home 25H2 (build 26200), plano "Elevado desempenho", ligado à corrente | igual |
| Modo do anfitrião | hipervisor ativo, escalonador *root* (`0x4`) | hipervisor desligado, `Monitor Mode: CPL0` |
| Versão | config. VM 12.0, Geração 2 | Workstation 17.6.4, HW v21 |
| Convidado | Ubuntu Server 26.04.1 LTS, kernel 7.0.0-38 | igual |
| vCPU / memória | 2 vCPU sem SMT / 4096 MB fixa | 2 vCPU sem SMT / 4096 MB |
| Disco | 25 GB `.vhdx` dinâmico, SCSI sintético | 25 GB `.vmdk` esparso, LSI Logic |
| Rede | `hv_netvsc`, Default Switch | `e1000`, NAT (VMnet8) |
| Ferramentas | sysbench 1.0.20, fio 3.41, iperf3 3.20 | igual |

---

## 2. Anfitrião (Windows — PowerShell como administrador)

Só uma VM corre de cada vez. Cada mudança de modo exige **reiniciar** o PC.

### Instalar o Hyper-V no Windows 11 Home

A edição Home não mostra o Hyper-V nas funcionalidades opcionais, mas os pacotes já vêm no sistema. O script [`0_instalar_hyperv_home.bat`](scripts/windows/0_instalar_hyperv_home.bat), executado **como administrador**, adiciona-os com o DISM e ativa a funcionalidade; no fim, reiniciar o PC.
```bat
pushd "%~dp0"
dir /b %SystemRoot%\servicing\Packages\*Hyper-V*.mum >hyper-v.txt
for /f %%i in ('findstr /i . hyper-v.txt 2^>nul') do dism /online /norestart /add-package:"%SystemRoot%\servicing\Packages\%%i"
del hyper-v.txt
Dism /online /enable-feature /featurename:Microsoft-Hyper-V -All /LimitAccess /ALL
pause
```

### Modo Hyper-V (escalonador *root*, o predefinido do Windows 11)
```powershell
bcdedit /set hypervisorlaunchtype auto
bcdedit /deletevalue hypervisorschedulertype
```

### Modo VMware (Tipo 2 nativo: o hipervisor do Windows desligado)
```powershell
bcdedit /set hypervisorlaunchtype off
# Integridade de Memória desligada (também depende do hipervisor):
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name Enabled -Value 0
```

### Experiência do escalonador (Hyper-V com escalonador *core*)
```powershell
bcdedit /set hypervisorschedulertype core
```

### Topologia de vCPU sem SMT no Hyper-V (com a VM desligada)
```powershell
Set-VMProcessor -VMName VM-Tipo1-HyperV -HwThreadCountPerCore 1
```

### Verificação do modo (depois de cada reinício)
```powershell
(Get-CimInstance Win32_ComputerSystem).HypervisorPresent      # True = Hyper-V | False = VMware
Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Hyper-V-Hypervisor';Id=2} -MaxEvents 1
                                                              # escalonador: 0x4 root | 0x3 core
Select-String "<pasta da VM>\vmware.log" -Pattern "Monitor Mode"   # tem de dizer CPL0
```

> ⚠️ Com o hipervisor do Windows ativo, o VMware Workstation corre em modo `ULM` (sobre o Hyper-V) e deixa de representar um Tipo 2. Confirme sempre `CPL0`.

---

## 3. Convidado (Ubuntu) — preparação

```bash
sudo apt update
sudo apt install -y sysbench fio iperf3
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer   # evita atualizações a meio dos testes
lscpu | grep -E "Socket|Core|Thread"                          # confirmar: 2 vCPU, 1 thread por núcleo
```

---

## 4. Processador

```bash
sysbench cpu --cpu-max-prime=20000 --threads=1 --time=10 run
sysbench cpu --cpu-max-prime=20000 --threads=2 --time=10 run
```
**Métricas:** eventos por segundo e latência (média, p95, máxima).

---

## 5. Memória

```bash
# escrita sequencial, bloco 1 KiB (residente em cache L1)
sysbench memory --threads=2 --memory-block-size=1K --memory-total-size=100G --time=10 run

# escrita e leitura sequenciais, bloco 1 MiB (largura de banda da RAM)
sysbench memory --threads=2 --memory-block-size=1M --memory-total-size=500G --memory-oper=write --time=10 run
sysbench memory --threads=2 --memory-block-size=1M --memory-total-size=500G --memory-oper=read  --time=10 run

# leitura aleatória num buffer de 256 MiB (falhas de TLB, tradução de endereços EPT/NPT)
sysbench memory --threads=2 --memory-block-size=256M --memory-total-size=500G \
                --memory-access-mode=rnd --memory-oper=read --time=10 run
```
**Métrica:** débito (MiB/s).

---

## 6. Disco

### Criar o ficheiro de teste (uma vez)
```bash
mkdir -p ~/fio_teste
fio --name=layout --filename=$HOME/fio_teste/fio_teste.dat --size=4G --rw=write --bs=1M \
    --direct=1 --ioengine=libaio --iodepth=16
```

### Antes de cada teste: limpar a cache de páginas do convidado
```bash
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
```

### Os seis perfis
```bash
B="--ioengine=libaio --direct=1 --filename=$HOME/fio_teste/fio_teste.dat --size=4G --numjobs=1 \
   --time_based --runtime=15 --ramp_time=3 --group_reporting --output-format=json"

fio $B --name=rr    --rw=randread  --bs=4k --iodepth=1                  # leitura aleatória, Q=1
fio $B --name=rw    --rw=randwrite --bs=4k --iodepth=1                  # escrita aleatória, Q=1
fio $B --name=rrw   --rw=randrw --rwmixread=50 --bs=4k --iodepth=1      # mista 50/50, Q=1
fio $B --name=rrw32 --rw=randrw --rwmixread=50 --bs=4k --iodepth=32     # mista 50/50, Q=32
fio $B --name=sr    --rw=read  --bs=1M --iodepth=16                     # leitura sequencial
fio $B --name=sw    --rw=write --bs=1M --iodepth=16                     # escrita sequencial
```
**Métricas:** IOPS, débito (MiB/s) e latência média e p99 (µs).

---

## 7. Rede

### No anfitrião (Windows)
```powershell
# abrir a firewall para o iperf3 e o ping
New-NetFirewallRule -DisplayName "VCD-iperf3-TCP" -Direction Inbound -Protocol TCP -LocalPort 5201 -Action Allow
New-NetFirewallRule -DisplayName "VCD-ping" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -Action Allow
# servidor (iperf3 3.22 para Windows)
iperf3.exe -s
```
O IP do anfitrião vê-se com `ipconfig`: adaptador `vEthernet (Default Switch)` no Hyper-V e `VMware Network Adapter VMnet8` no VMware.

### No convidado (`H` = IP do anfitrião)
```bash
iperf3 -c H -t 10 -J          # TCP convidado -> anfitrião
iperf3 -c H -t 10 -R -J       # TCP anfitrião -> convidado
iperf3 -c H -t 10 -P 4 -J     # TCP com 4 ligações paralelas
ping -c 50 -i 0.2 -q H        # latência ida-e-volta (RTT)
```

### UDP: jitter e perda (no convidado)
```bash
iperf3 -u -c H -t 10 -J            # 1 Mbit/s (predefinido do iperf3, como em Louro, 2018)
iperf3 -u -c H -b 100M -t 10 -J    # 100 Mbit/s: jitter com carga moderada
iperf3 -u -c H -b 1G -t 10 -J      # 1 Gbit/s: débito máximo e perda
```
A regra de firewall para UDP na porta 5201 também é necessária:
```powershell
New-NetFirewallRule -DisplayName "VCD-iperf3-UDP" -Direction Inbound -Protocol UDP -LocalPort 5201 -Action Allow
```
**Métricas:** débito (Mbit/s), CPU usada pelo iperf3 no anfitrião e no convidado, RTT médio, máximo e desvio; em UDP, jitter (ms) e perda de pacotes (%).

---

## 8. Procedimento

1. Pôr o anfitrião no modo certo (secção 2), reiniciar, confirmar o modo e **esperar 10 minutos** sem usar o PC.
2. Fechar as aplicações do anfitrião, pausar o OneDrive e o Windows Update, e excluir as pastas das VMs da análise do Microsoft Defender.
3. Arrancar **só** a VM a testar e prepará-la (secção 3).
4. Fazer **uma corrida de aquecimento** de todos os testes e descartá-la.
5. Fazer **10 repetições**. Em cada repetição:
   - correr, por esta ordem, os testes de processador (4), memória (5) e disco (6), com pausas de 5 s;
   - limpar a cache antes de cada teste `fio`.
6. Para a rede: um aquecimento de 3 s e 10 repetições dos quatro comandos TCP/ping da secção 7, com pausas de 2 s; depois, da mesma forma, os três comandos UDP.

---

## 9. Execução automática com os scripts

Tudo o que está acima é feito pelos scripts:

```bash
chmod +x bench.sh rede.sh
./bench.sh hyperv            # ou: ./bench.sh vmware   (~40 min, cria resultados_<cenário>_<data>.tar.gz)
./rede.sh hyperv 172.x.x.1   # ou: ./rede.sh vmware 192.168.x.1   (~9 min)
./rede_udp.sh hyperv 172.x.x.1   # ou: ./rede_udp.sh vmware 192.168.x.1   (~7 min)
ONLY_CPU=1 ./bench.sh hypervcorenosmt   # experiência do escalonador (só CPU)
```

Cada pasta de resultados inclui o `ambiente.txt` (sistema, `lscpu`, discos, versões e N) e as saídas originais:

| Ficheiro | Ferramenta |
|---|---|
| `cpu_*_NN.txt`, `mem_*_NN.txt` | sysbench |
| `fio_*_NN.json` | fio |
| `net_tcp_*_NN.json`, `net_udp_*_NN.json` | iperf3 |
| `net_ping_NN.txt` | ping |

`NN` = número da repetição (01 a 10).

---

## 10. Processamento dos resultados

```bash
python3 parse_resultados.py resultados_hyperv_* resultados_vmware_* resultados_hypervcorenosmt_* \
                            resultados_rede_hyperv_* resultados_rede_vmware_* \
                            resultados_rede_udp_hyperv_* resultados_rede_udp_vmware_*
```
O script gera três ficheiros:

| Ficheiro | Conteúdo |
|---|---|
| `corridas.csv` | um valor por repetição |
| `resumo.csv` | média, desvio-padrão amostral, IC95 (t de Student) e CV |
| `comparacao.csv` | Δ% face ao primeiro cenário indicado (Hyper-V *root*) |

Os testes t de Welch estão calculados, com fórmulas, no ficheiro `resultados_vcd.xlsx`.

---

## 11. Referência: o sistema sem virtualização

O *overhead* de cada hipervisor foi quantificado face ao mesmo portátil **sem nenhuma máquina virtual**, com a mesma ferramenta e os mesmos parâmetros de cada subsistema. Como o `sysbench` 1.0 não tem versão nativa para Windows, há duas referências:

| Subsistema | Referência | Como | Nota |
|---|---|---|---|
| Processador e memória | Ubuntu 26.04.1 nativo (*live* USB) | `nativo_pen.sh` → `bench.sh` com `SKIP_FIO=1` | o mesmo `sysbench` 1.0.20 das VMs; turbo desligado (11.2) |
| Disco | Windows anfitrião, hipervisor desligado | `7_fio_anfitriao.ps1` | `fio` 3.41, os mesmos 6 perfis, `windowsaio`, `direct=1` |
| Rede | Windows anfitrião, *loopback* 127.0.0.1 | `9_rede_loopback.ps1` | `iperf3` 3.22; limite superior da pilha do anfitrião (indicativo) |

### 11.1 Windows anfitrião (disco e rede)

Condições: anfitrião em **modo VMware** (`3_modo_vmware.ps1` + reinício), confirmado com `4_verificar_estado.ps1` (`Hipervisor presente: False`); nenhuma VM ligada; aplicações fechadas; plano "Elevado desempenho"; ligado à corrente; 10 minutos depois do arranque.

```powershell
# PowerShell como administrador, na pasta scripts\windows
powershell -ExecutionPolicy Bypass -File .\7_fio_anfitriao.ps1 -Fio "C:\Program Files\fio\fio.exe" -Dir C:\vcd\fio_teste   # ~25 min
powershell -ExecutionPolicy Bypass -File .\9_rede_loopback.ps1 -Iperf "C:\iperf3\iperf3.exe"                              # ~7 min
```

Comandos executados pelos scripts (N = 10, com aquecimento):
```powershell
# disco: os 6 perfis da secção 6, com estas opções base
fio --ioengine=windowsaio --direct=1 --thread --filename=C:\vcd\fio_teste\fio_teste.dat --size=4G `
    --numjobs=1 --time_based --runtime=15 --ramp_time=3 --group_reporting --output-format=json ...
# rede (servidor iperf3 -s noutra janela)
iperf3 -c 127.0.0.1 -t 10 -J
iperf3 -c 127.0.0.1 -t 10 -R -J
iperf3 -c 127.0.0.1 -t 10 -P 4 -J
```

### 11.2 Ubuntu nativo em *live* USB (processador e memória)

O mesmo portátil arranca o Ubuntu 26.04.1 Desktop a partir de uma pen (modo "Experimentar", sem instalar nada), diretamente no hardware. Sem disco: no *live* USB a raiz está em RAM.

**Frequência.** Medições no Windows anfitrião mostraram que este corre sempre a ≈2,35 GHz sob carga, sem turbo, em todos os planos de energia; foi essa a frequência a que correram as VMs. O Ubuntu nativo, com turbo, chega a ≈4 GHz (+67–71% no processador), o que mediria a frequência e não a virtualização. Por isso, a referência usada desliga o turbo (máximo 2400 MHz):

```bash
# 1) modo de energia "Desempenho" (Definições > Energia; ou: powerprofilesctl set performance)
# 2) desligar o turbo e confirmar
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
lscpu -e        # MAXMHZ tem de ser 2400
# 3) correr a bateria (na pasta scripts/ubuntu do repositório)
sudo bash nativo_pen.sh        # ~25 min
```

O `nativo_pen.sh` impede a suspensão, escolhe dois núcleos físicos diferentes, guarda `lscpu -e` em `info_cpu_nativo.txt`, ativa o perfil "performance" (se existir) e corre `SKIP_FIO=1 taskset -c <2 núcleos> ./bench.sh nativo`. **Tudo fica em RAM**: copiar a pasta de resultados para fora antes de desligar.

Pastas de resultados: `resultados_nativo_semturbo_*` (referência, sem turbo) e `resultados_nativo_turbo_*` (só registo do efeito da frequência).

### 11.3 Processamento (a PRIMEIRA pasta é a referência)
```bash
python3 parse_resultados.py resultados_nativo_semturbo_* resultados_hyperv_2* resultados_vmware_2*        # CPU e memória
python3 parse_resultados.py resultados_anfitriao_*       resultados_hyperv_2* resultados_vmware_2*        # disco
python3 parse_resultados.py resultados_rede_anfitriao_*  resultados_rede_hyperv_* resultados_rede_vmware_* # rede
```
Correr cada linha numa pasta diferente (cada execução reescreve os CSV). O `comparacao.csv` dá o *overhead* de cada hipervisor face à referência. No `resultados_vcd.xlsx`, a folha **Overhead nativo** calcula o mesmo com fórmulas e testes t de Welch.

---

## 12. VMware com placa paravirtualizada vmxnet3 (opcional)

> Não executado neste trabalho (o relatório usa a configuração predefinida, `e1000`). Fica como procedimento para trabalho futuro.

Testa a explicação do relatório: a diferença de rede deve-se à placa emulada `e1000`.

1. Desligar a VM e **copiar a pasta da VM** (cópia de segurança).
2. No ficheiro `.vmx`, trocar `ethernet0.virtualDev = "e1000"` por `ethernet0.virtualDev = "vmxnet3"`.
3. Arrancar no modo VMware (`Monitor Mode: CPL0`). O nome da interface muda (por exemplo, de `ens33` para `ens160`), por isso pode ser preciso corrigir o nome no netplan:
   ```bash
   ip -br a                                   # ver o novo nome
   sudo nano /etc/netplan/50-cloud-init.yaml  # trocar ens33 pelo novo nome
   sudo netplan apply
   ```
4. Correr:
   ```bash
   ./rede.sh vmwarevmxnet3 192.168.59.1
   ./rede_udp.sh vmwarevmxnet3 192.168.59.1
   ```
   Confirmar em `ambiente_rede.txt` que o *driver* é `vmxnet3`.
5. No fim, repor `e1000` (ou a cópia de segurança).
