"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { Dimension, Grado, PautaEstado } from "@/lib/types";
import { GRADOS, gradoLabel, SEMAFORO_COLOR } from "@/lib/sinaes";

const CAT_STYLE: Record<string, { bg: string; fg: string }> = {
  A: { bg: "#FCEBEB", fg: "#A32D2D" },
  B: { bg: "#FAEEDA", fg: "#854F0B" },
  C: { bg: "#E6F1FB", fg: "#0C447C" },
  D: { bg: "#F1EFE8", fg: "#444441" },
};

export default function PautasBoard({
  procesoId,
  dimensiones,
  pautas,
}: {
  procesoId: string;
  dimensiones: Dimension[];
  pautas: PautaEstado[];
}) {
  const router = useRouter();
  const supabase = createClient();

  const [dimFiltro, setDimFiltro] = useState<number | "todas">("todas");
  const [busqueda, setBusqueda] = useState("");
  const [soloPendientes, setSoloPendientes] = useState(false);

  const [sel, setSel] = useState<PautaEstado | null>(null);
  const [grado, setGrado] = useState<Grado>("conforme");
  const [argumento, setArgumento] = useState("");
  const [fuentes, setFuentes] = useState<{ tipo: string; nombre: string }[]>([]);
  const [guardando, setGuardando] = useState(false);

  const filtradas = useMemo(() => {
    const q = busqueda.trim().toLowerCase();
    return pautas.filter((p) => {
      if (dimFiltro !== "todas" && p.dimension_id !== dimFiltro) return false;
      if (soloPendientes && p.grado !== "no_evaluada") return false;
      if (q && !(`${p.codigo} ${p.nombre}`.toLowerCase().includes(q))) return false;
      return true;
    });
  }, [pautas, dimFiltro, busqueda, soloPendientes]);

  const porDimension = useMemo(() => {
    return dimensiones
      .map((d) => ({
        dim: d,
        items: filtradas.filter((p) => p.dimension_id === d.id),
      }))
      .filter((g) => g.items.length > 0);
  }, [dimensiones, filtradas]);

  async function abrir(p: PautaEstado) {
    setSel(p);
    setGrado(p.grado === "no_evaluada" ? "conforme" : p.grado);
    setArgumento(p.argumentacion ?? "");
    setFuentes([]);
    const { data } = await supabase
      .from("fuentes")
      .select("tipo,nombre")
      .eq("pauta_id", p.pauta_id)
      .order("orden");
    setFuentes((data as { tipo: string; nombre: string }[]) ?? []);
  }

  async function guardar() {
    if (!sel) return;
    setGuardando(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();

    const { error } = await supabase.from("evaluaciones").upsert(
      {
        proceso_id: procesoId,
        pauta_id: sel.pauta_id,
        grado,
        argumentacion: argumento,
        conformidad: null, // la BD deriva el % desde el grado
        evaluado_por: user?.id ?? null,
      },
      { onConflict: "proceso_id,pauta_id" },
    );

    setGuardando(false);
    if (!error) {
      setSel(null);
      router.refresh();
    }
  }

  return (
    <div className="mt-5">
      <div className="flex flex-wrap items-center gap-2">
        <select
          value={dimFiltro}
          onChange={(e) =>
            setDimFiltro(e.target.value === "todas" ? "todas" : Number(e.target.value))
          }
          className="rounded-lg border border-black/15 px-3 py-2 text-sm"
        >
          <option value="todas">Todas las dimensiones</option>
          {dimensiones.map((d) => (
            <option key={d.id} value={d.id}>
              {d.codigo} · {d.nombre}
            </option>
          ))}
        </select>
        <input
          type="text"
          placeholder="Buscar pauta…"
          value={busqueda}
          onChange={(e) => setBusqueda(e.target.value)}
          className="flex-1 rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
        />
        <label className="flex items-center gap-2 text-sm text-neutral-600">
          <input
            type="checkbox"
            checked={soloPendientes}
            onChange={(e) => setSoloPendientes(e.target.checked)}
          />
          Solo pendientes
        </label>
      </div>

      <div className="mt-5 space-y-6">
        {porDimension.map(({ dim, items }) => (
          <div key={dim.id}>
            <p className="mb-2 text-sm font-medium text-neutral-700">
              {dim.codigo} · {dim.nombre}
              <span className="ml-2 text-xs font-normal text-neutral-400">
                {items.length} pautas
              </span>
            </p>
            <div className="overflow-hidden rounded-xl border border-black/10 bg-white">
              {items.map((p, i) => {
                const cat = CAT_STYLE[p.categoria];
                return (
                  <button
                    key={p.pauta_id}
                    onClick={() => abrir(p)}
                    className={`flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-neutral-50 ${
                      i > 0 ? "border-t border-black/5" : ""
                    }`}
                  >
                    <span
                      className="h-2.5 w-2.5 shrink-0 rounded-full"
                      style={{ background: SEMAFORO_COLOR[p.semaforo] }}
                    />
                    <span className="w-8 shrink-0 text-sm font-medium text-neutral-500">
                      {p.codigo}
                    </span>
                    <span
                      className="shrink-0 rounded px-1.5 py-0.5 text-[11px] font-medium"
                      style={{ background: cat.bg, color: cat.fg }}
                    >
                      {p.categoria}
                    </span>
                    <span className="flex-1 truncate text-sm text-neutral-800">
                      {p.nombre}
                    </span>
                    <span className="shrink-0 text-xs text-neutral-400">
                      {p.num_evidencias > 0 ? `${p.num_evidencias} evid.` : "—"}
                    </span>
                    <span className="hidden w-36 shrink-0 text-right text-xs text-neutral-500 sm:block">
                      {gradoLabel(p.grado)}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
        {porDimension.length === 0 && (
          <p className="text-sm text-neutral-500">
            No hay pautas que coincidan con el filtro.
          </p>
        )}
      </div>

      {sel && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          onClick={() => setSel(null)}
        >
          <div
            className="max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-xl bg-white p-6"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-1 flex items-center gap-2">
              <span className="text-sm font-medium text-neutral-500">
                Pauta {sel.codigo}
              </span>
              <span
                className="rounded px-1.5 py-0.5 text-[11px] font-medium"
                style={{
                  background: CAT_STYLE[sel.categoria].bg,
                  color: CAT_STYLE[sel.categoria].fg,
                }}
              >
                Categoría {sel.categoria}
              </span>
            </div>
            <p className="text-sm leading-relaxed text-neutral-800">{sel.nombre}</p>

            {fuentes.length > 0 && (
              <div className="mt-4">
                <p className="mb-1 text-xs font-medium text-neutral-500">
                  Fuentes de información sugeridas
                </p>
                <ul className="space-y-1">
                  {fuentes.map((f, i) => (
                    <li key={i} className="flex gap-2 text-xs text-neutral-600">
                      <span className="shrink-0 rounded bg-neutral-100 px-1.5 py-0.5 font-medium">
                        Tipo {f.tipo}
                      </span>
                      <span>{f.nombre}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div className="mt-5">
              <label className="mb-1 block text-xs font-medium text-neutral-500">
                Grado de conformidad
              </label>
              <select
                value={grado}
                onChange={(e) => setGrado(e.target.value as Grado)}
                className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm"
              >
                {GRADOS.filter((g) => g.value !== "no_evaluada").map((g) => (
                  <option key={g.value} value={g.value}>
                    {g.label}
                  </option>
                ))}
              </select>
            </div>

            <div className="mt-3">
              <label className="mb-1 block text-xs font-medium text-neutral-500">
                Argumentación
              </label>
              <textarea
                value={argumento}
                onChange={(e) => setArgumento(e.target.value)}
                rows={5}
                placeholder="Describe la evidencia y el análisis que respaldan esta valoración…"
                className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
              />
            </div>

            <div className="mt-5 flex justify-end gap-2">
              <button
                onClick={() => setSel(null)}
                className="rounded-lg px-4 py-2 text-sm text-neutral-600 hover:bg-neutral-100"
              >
                Cancelar
              </button>
              <button
                onClick={guardar}
                disabled={guardando}
                className="rounded-lg bg-marca-600 px-4 py-2 text-sm font-medium text-white hover:bg-marca-800 disabled:opacity-60"
              >
                {guardando ? "Guardando…" : "Guardar evaluación"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
