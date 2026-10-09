#!/usr/bin/env python3
"""Extrae dimensiones, pautas y fuentes del Formato 1 oficial del SINAES.
Hoja fuente: '4.1 Valoración de pautas C1'. Columnas (1-based):
  1=Categoría 2=Dimensión 3=Pauta 4=Fuente 5=Tipo 6=Argumentación 7=Grado ...
Salida: supabase/import/modelo_grado_2025.json
"""
import sys, json, re, openpyxl
from pathlib import Path

CATS = {"A", "B", "C", "D"}

def norm(v):
    if v is None: return ""
    return str(v).replace("\xa0", " ").strip()

def num_prefijo(texto):
    m = re.match(r"^\s*(\d+)[\.\)]", texto)
    return m.group(1) if m else None

def limpiar(texto):
    return re.sub(r"^\s*\d+[\.\)]\s*", "", texto).strip()

def tipo_norm(t):
    m = re.search(r"\b(IV|III|II|I)\b", t.upper())
    return m.group(1) if m else None

def es_header(fcol, tcol):
    """Filas de encabezado repetidas por dimensión (no son fuentes reales)."""
    f, t = fcol.lower(), tcol.lower()
    return f.startswith("fuente de informaci") or t.startswith("tipo de fuente")

def reg_dim(dims, numero, nombre):
    if numero and not any(d["numero"] == numero for d in dims):
        dims.append({"numero": numero, "codigo": f"D{numero}", "nombre": nombre.strip(" .")})

def main(path):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb["4.1 Valoración de pautas C1"]
    dimensiones, pautas = [], []
    dim_actual, pauta_actual = None, None
    for row in ws.iter_rows(values_only=True):
        g = lambda i: norm(row[i]) if len(row) > i else ""
        c1, dimcell, pcol, fcol, tcol = g(1), g(2), g(3), g(4), g(5)

        mt = re.match(r"^Dimensi[oó]n\s+(\d+)\.?\s*(.*)$", c1, re.I)
        if mt and c1 not in CATS:
            reg_dim(dimensiones, mt.group(1), mt.group(2))
            dim_actual = mt.group(1)
            continue

        if c1 in CATS and num_prefijo(pcol):
            md = re.match(r"^Dimensi[oó]n\s+(\d+)\.?\s*(.*)$", dimcell, re.I)
            if md:
                reg_dim(dimensiones, md.group(1), md.group(2))
                dim_actual = md.group(1)
            pauta_actual = {
                "numero": num_prefijo(pcol),
                "categoria": c1,
                "dimension_num": dim_actual,
                "enunciado": limpiar(pcol),
                "fuentes": [],
            }
            pautas.append(pauta_actual)
            if fcol and not es_header(fcol, tcol):
                pauta_actual["fuentes"].append({"tipo": tipo_norm(tcol), "nombre": limpiar(fcol)})
            continue

        if pauta_actual is not None and fcol and c1 not in CATS and not es_header(fcol, tcol):
            pauta_actual["fuentes"].append({"tipo": tipo_norm(tcol), "nombre": limpiar(fcol)})

    return {"dimensiones": dimensiones, "pautas": pautas}

if __name__ == "__main__":
    data = main(sys.argv[1])
    out = Path(__file__).parent / "modelo_grado_2025.json"
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"DIMENSIONES: {len(data['dimensiones'])}")
    for d in data["dimensiones"]:
        n = sum(1 for p in data["pautas"] if p["dimension_num"] == d["numero"])
        print(f"  {d['codigo']}: {d['nombre']}  ->  {n} pautas")
    print(f"TOTAL PAUTAS: {len(data['pautas'])}")
    cats = {}
    for p in data["pautas"]:
        cats[p["categoria"]] = cats.get(p["categoria"], 0) + 1
    print("POR CATEGORÍA:", dict(sorted(cats.items())))
    nulos = sum(1 for p in data["pautas"] for f in p["fuentes"] if not f["tipo"])
    print(f"TOTAL FUENTES: {sum(len(p['fuentes']) for p in data['pautas'])}  (sin tipo: {nulos})")
