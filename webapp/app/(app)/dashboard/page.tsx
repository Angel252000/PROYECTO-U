import { createClient } from "@/lib/supabase/server";
import { getProcesoActual } from "@/lib/proceso";
import type { DashboardKPIs, DimensionScore } from "@/lib/types";
import DashboardCharts from "@/components/DashboardCharts";
import EtapasProceso from "@/components/EtapasProceso";
import SinProceso from "@/components/SinProceso";

export default async function DashboardPage() {
  const proceso = await getProcesoActual();
  if (!proceso) return <SinProceso />;

  const supabase = createClient();
  const [{ data: kpis }, { data: dims }] = await Promise.all([
    supabase.from("vw_dashboard").select("*").eq("proceso_id", proceso.id).maybeSingle(),
    supabase
      .from("vw_dimension_scores")
      .select("*")
      .eq("proceso_id", proceso.id)
      .order("dimension_id"),
  ]);

  const k = (kpis as DashboardKPIs) ?? null;
  const dimensiones = (dims as DimensionScore[]) ?? [];

  const card = "rounded-lg bg-neutral-50 p-4";
  const label = "text-[13px] text-neutral-500";
  const valor = "mt-1.5 text-2xl font-medium";

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-1 flex items-start justify-between">
        <div>
          <h1 className="text-lg font-medium">{proceso.nombre}</h1>
          <p className="text-sm text-neutral-500">
            Modelo {proceso.modelo} · {proceso.anio}
          </p>
        </div>
      </div>

      <EtapasProceso estado={proceso.estado} />

      <div className="mt-6 grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className={card}>
          <p className={label}>Progreso general</p>
          <p className={valor}>
            {k ? Math.round(k.progreso_pct) : 0}
            <span className="text-base text-neutral-500">%</span>
          </p>
        </div>
        <div className={card}>
          <p className={label}>Pautas evaluadas</p>
          <p className={valor}>
            {k?.pautas_evaluadas ?? 0}
            <span className="text-base text-neutral-500"> / {k?.total_pautas ?? 59}</span>
          </p>
        </div>
        <div className={card}>
          <p className={label}>Puntaje</p>
          <p className={valor}>
            {k ? Number(k.puntaje_obtenido).toFixed(1) : "0.0"}
            <span className="text-base text-neutral-500">
              {" "}
              / {k ? Number(k.puntaje_max).toFixed(1) : "0.0"}
            </span>
          </p>
        </div>
        <div className={card}>
          <p className={label}>Semáforo auditor</p>
          <div className="mt-2 flex gap-3 text-sm font-medium">
            <span style={{ color: "#639922" }}>● {k?.en_verde ?? 0}</span>
            <span style={{ color: "#BA7517" }}>● {k?.en_amarillo ?? 0}</span>
            <span style={{ color: "#E24B4A" }}>● {k?.en_rojo ?? 0}</span>
          </div>
        </div>
      </div>

      <DashboardCharts dimensiones={dimensiones} />
    </div>
  );
}
