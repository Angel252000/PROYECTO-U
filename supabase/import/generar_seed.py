#!/usr/bin/env python3
"""Genera supabase/seed.sql (datos REALES del modelo) desde el JSON extraído."""
import json
from pathlib import Path

base = Path(__file__).parent
data = json.loads((base / "modelo_grado_2025.json").read_text(encoding="utf-8"))

def q(s):
    return "'" + (s or "").replace("'", "''") + "'"

L = []
L.append("-- =====================================================================")
L.append("-- SINAES · SEED del MODELO DE GRADO 2025  (DATOS OFICIALES REALES)")
L.append("-- =====================================================================")
L.append("-- GENERADO automáticamente desde el 'Formato 1' oficial del SINAES.")
L.append("-- NO editar a mano. Regenerar con:")
L.append("--   ./.venv-import/bin/python supabase/import/generar_seed.py")
L.append(f"-- Contenido: {len(data['dimensiones'])} dimensiones, {len(data['pautas'])} pautas, "
         f"{sum(len(p['fuentes']) for p in data['pautas'])} fuentes.")
L.append("-- =====================================================================\n")

# --- DIMENSIONES ---
L.append("-- DIMENSIONES (6)")
L.append("insert into dimensiones (codigo, nombre, orden) values")
rows = [f"  ({q(d['codigo'])}, {q(d['nombre'])}, {int(d['numero'])})" for d in data["dimensiones"]]
L.append(",\n".join(rows))
L.append("on conflict (codigo) do update set nombre = excluded.nombre, orden = excluded.orden;\n")

# --- PAUTAS ---
L.append(f"-- PAUTAS ({len(data['pautas'])})")
L.append("insert into pautas (dimension_id, codigo, nombre, categoria, orden) values")
rows = []
for p in data["pautas"]:
    dim = f"(select id from dimensiones where codigo = 'D{p['dimension_num']}')"
    rows.append(f"  ({dim}, {q(p['numero'])}, {q(p['enunciado'])}, "
                f"{q(p['categoria'])}::categoria_pauta, {int(p['numero'])})")
L.append(",\n".join(rows))
L.append("on conflict (codigo) do update set dimension_id = excluded.dimension_id, "
         "nombre = excluded.nombre, categoria = excluded.categoria, orden = excluded.orden;\n")

# --- FUENTES ---
total_f = sum(len(p["fuentes"]) for p in data["pautas"])
L.append(f"-- FUENTES ({total_f}) — se recarga todo el catálogo")
L.append("delete from fuentes;")
L.append("insert into fuentes (pauta_id, tipo, nombre, orden) values")
rows = []
for p in data["pautas"]:
    pid = f"(select id from pautas where codigo = {q(p['numero'])})"
    for i, f in enumerate(p["fuentes"], start=1):
        rows.append(f"  ({pid}, {q(f['tipo'])}::tipo_fuente, {q(f['nombre'])}, {i})")
L.append(",\n".join(rows) + ";")

out = base.parent / "seed.sql"
out.write_text("\n".join(L) + "\n", encoding="utf-8")
print(f"Generado: {out}  ({len(L)} bloques, {out.stat().st_size} bytes)")
