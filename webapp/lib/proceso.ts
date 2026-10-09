import { createClient } from "@/lib/supabase/server";
import type { Proceso } from "./types";

// Devuelve el proceso de autoevaluación "actual" del usuario.
// (Por ahora, el más reciente al que pertenece. Más adelante: selector.)
export async function getProcesoActual(): Promise<Proceso | null> {
  const supabase = createClient();
  const { data } = await supabase
    .from("procesos")
    .select("*")
    .order("anio", { ascending: false })
    .limit(1)
    .maybeSingle();

  return (data as Proceso) ?? null;
}
