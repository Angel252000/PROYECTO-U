import { createClient } from "@/lib/supabase/server";
import { getProcesoActual } from "@/lib/proceso";
import type { Dimension, PautaEstado } from "@/lib/types";
import PautasBoard from "@/components/PautasBoard";
import SinProceso from "@/components/SinProceso";

export default async function PautasPage() {
  const proceso = await getProcesoActual();
  if (!proceso) return <SinProceso />;

  const supabase = createClient();
  const [{ data: dims }, { data: pautas }] = await Promise.all([
    supabase.from("dimensiones").select("*").order("orden"),
    supabase
      .from("vw_pauta_estado")
      .select("*")
      .eq("proceso_id", proceso.id)
      .order("pauta_id"),
  ]);

  return (
    <div className="mx-auto max-w-5xl">
      <h1 className="text-lg font-medium">Pautas de calidad</h1>
      <p className="text-sm text-neutral-500">
        {proceso.nombre} · evalúa cada pauta del modelo
      </p>

      <PautasBoard
        procesoId={proceso.id}
        dimensiones={(dims as Dimension[]) ?? []}
        pautas={(pautas as PautaEstado[]) ?? []}
      />
    </div>
  );
}
