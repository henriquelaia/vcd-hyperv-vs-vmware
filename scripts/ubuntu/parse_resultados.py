#!/usr/bin/env python3
"""
parse_resultados.py — converte as pastas criadas pelo bench.sh em CSV.

    python3 parse_resultados.py resultados_hyperv_* resultados_vmware_* \
                                resultados_rede_hyperv_* resultados_rede_vmware_* \
                                resultados_rede_udp_hyperv_* resultados_rede_udp_vmware_*

  Com a referência do anfitrião (a PRIMEIRA pasta define a referência):
    python3 parse_resultados.py resultados_anfitriao_* resultados_hyperv_2* resultados_vmware_2*
    python3 parse_resultados.py resultados_7z_anfitriao_* resultados_7z_hyperv_* resultados_7z_vmware_*
    python3 parse_resultados.py resultados_rede_anfitriao_* resultados_rede_hyperv_* resultados_rede_vmware_*

Gera:
  corridas.csv     — um valor por corrida
  resumo.csv       — média, desvio-padrão amostral, IC95% (t de Student), CV%
  comparacao.csv   — Δ% de cada etiqueta face à PRIMEIRA pasta indicada
Só usa a biblioteca padrão do Python.
"""
import csv, json, re, statistics as st, sys
from pathlib import Path

T975 = {1:12.706,2:4.303,3:3.182,4:2.776,5:2.571,6:2.447,7:2.365,8:2.306,9:2.262,
        10:2.228,11:2.201,12:2.179,13:2.160,14:2.145,15:2.131,19:2.093,29:2.045}

def t975(df):
    return T975.get(df) or T975[min(T975, key=lambda k: abs(k - df))]

def parse_sysbench(txt):
    m = {}
    g = lambda p: (re.search(p, txt) or [None, None])[1]
    if (v := g(r"events per second:\s+([\d.]+)")):        m["eventos_s"] = float(v)
    if (v := g(r"\(([\d.]+) MiB/sec\)")):                  m["mib_s"] = float(v)
    if (v := g(r"Total operations:\s+\d+\s+\(([\d.]+) per second\)")): m["ops_s"] = float(v)
    if (v := g(r"avg:\s+([\d.]+)")):                       m["lat_media_ms"] = float(v)
    if (v := g(r"95th percentile:\s+([\d.]+)")):           m["lat_p95_ms"] = float(v)
    if (v := g(r"max:\s+([\d.]+)")):                       m["lat_max_ms"] = float(v)
    return m

def parse_7z(txt):
    # linhas finais do "7z b": Avr (compressão | descompressão) e Tot; a última
    # coluna de cada parte é o rating em MIPS
    m = {}
    ints = lambda s: [int(x) for x in re.findall(r"\d+", s)]
    if (x := re.search(r"^Avr:(.*)\|(.*)$", txt, re.M)):
        m["compressao_mips"] = ints(x[1])[-1]
        m["descompressao_mips"] = ints(x[2])[-1]
    if (x := re.search(r"^Tot:(.*)$", txt, re.M)):
        m["total_mips"] = ints(x[1])[-1]
    return m

def parse_iperf(data):
    end = data["end"]
    proto = data.get("start", {}).get("test_start", {}).get("protocol", "TCP")
    if proto == "UDP":                                       # UDP: lado recetor
        u = end.get("sum_received") or end["sum"]
        m = {"mbit_s": u["bits_per_second"] / 1e6,
             "jitter_ms": u.get("jitter_ms", 0.0),
             "perda_pct": u.get("lost_percent", 0.0)}
        cpu = end.get("cpu_utilization_percent", {})
        if "remote_total" in cpu:
            m["cpu_anfitriao_pct"] = cpu["remote_total"]
        return m
    m = {"mbit_s": end["sum_received"]["bits_per_second"] / 1e6}
    if "retransmits" in end.get("sum_sent", {}):
        m["retransmissoes"] = end["sum_sent"]["retransmits"]
    cpu = end.get("cpu_utilization_percent", {})
    if "host_total" in cpu:
        m["cpu_convidado_pct"] = cpu["host_total"]
    if "remote_total" in cpu:
        m["cpu_anfitriao_pct"] = cpu["remote_total"]
    return m

def parse_ping(txt):
    m = {}
    if (x := re.search(r"= ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ms", txt)):
        m.update(rtt_min_ms=float(x[1]), rtt_media_ms=float(x[2]),
                 rtt_max_ms=float(x[3]), rtt_mdev_ms=float(x[4]))
    if (x := re.search(r"([\d.]+)% packet loss", txt)):
        m["perda_pct"] = float(x[1])
    return m

def parse_json(path):
    data = json.loads(Path(path).read_text())
    return parse_iperf(data) if "end" in data and "jobs" not in data else parse_fio(data)

def parse_fio(data):
    job = data["jobs"][0]
    m = {}
    for d in ("read", "write"):
        x = job[d]
        if x["io_bytes"] == 0:
            continue
        m[f"{d}_iops"] = x["iops"]
        m[f"{d}_mib_s"] = x["bw"] / 1024
        m[f"{d}_lat_media_us"] = x["lat_ns"]["mean"] / 1000
        pct = x["clat_ns"].get("percentile", {})
        if "99.000000" in pct:
            m[f"{d}_lat_p99_us"] = pct["99.000000"] / 1000
    if "read_iops" in m and "write_iops" in m:
        m["total_iops"] = m["read_iops"] + m["write_iops"]
        m["total_mib_s"] = m["read_mib_s"] + m["write_mib_s"]
    return m

def tag_of(d):
    mm = re.match(r"resultados_(?:rede_udp_|rede_|7z_)?(.+?)_\d{8}_\d{4}$", Path(d).name)
    return mm[1] if mm else Path(d).name.split("_")[1]

def main(dirs):
    rows = []
    dirs = [d for d in dirs if Path(d).is_dir()]
    for d in map(Path, dirs):
        tag = tag_of(d)
        for f in sorted(d.iterdir()):
            mm = re.match(r"(.+)_(\d{1,2})\.(txt|json)$", f.name)
            if not mm:
                continue
            test, run = mm[1], int(mm[2])
            if f.suffix == ".json":
                vals = parse_json(f)
            elif test.startswith("net_ping"):
                vals = parse_ping(f.read_text())
            elif test.startswith("cpu7z"):
                vals = parse_7z(f.read_text(errors="replace"))
            else:
                vals = parse_sysbench(f.read_text())
            for k, v in vals.items():
                rows.append(dict(tag=tag, teste=test, metrica=k, corrida=run, valor=v))

    with open("corridas.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)

    groups = {}
    for r in rows:
        groups.setdefault((r["tag"], r["teste"], r["metrica"]), []).append(r["valor"])
    resumo = []
    for (tag, teste, met), xs in groups.items():
        n = len(xs); mu = st.mean(xs); sd = st.stdev(xs) if n > 1 else 0.0
        ic = t975(n - 1) * sd / n ** 0.5 if n > 1 else 0.0
        resumo.append(dict(tag=tag, teste=teste, metrica=met, n=n, media=round(mu, 4),
                           desvio=round(sd, 4), ic95=round(ic, 4),
                           cv_pct=round(100 * sd / mu, 2) if mu else 0))
    with open("resumo.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=resumo[0].keys()); w.writeheader(); w.writerows(resumo)

    ref = tag_of(dirs[0])
    idx = {(r["tag"], r["teste"], r["metrica"]): r for r in resumo}
    comp = []
    for (tag, teste, met), r in idx.items():
        if tag == ref or (ref, teste, met) not in idx:
            continue
        b = idx[(ref, teste, met)]
        comp.append(dict(teste=teste, metrica=met, referencia=ref, media_ref=b["media"],
                         alvo=tag, media_alvo=r["media"],
                         delta_pct=(round(100 * (r["media"] - b["media"]) / b["media"], 2)
                                    if b["media"] else "")))
    if comp:
        with open("comparacao.csv", "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=comp[0].keys()); w.writeheader(); w.writerows(comp)
    print(f"{len(rows)} valores -> corridas.csv, resumo.csv" + (", comparacao.csv" if comp else ""))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
