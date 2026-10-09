"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function SinProceso() {
  const router = useRouter();
  const supabase = createClient();
  const [institucion, setInstitucion] = useState("");
  const [carrera, setCarrera] = useState("");
  const [anio, setAnio] = useState(new Date().getFullYear());
  const [error, setError] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);

  async function crear(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setCargando(true);

    const { data: inst, error: e1 } = await supabase
      .from("instituciones")
      .insert({ nombre: institucion })
      .select("id")
      .single();
    if (e1 || !inst) return fallo(e1?.message);

    const { data: car, error: e2 } = await supabase
      .from("carreras")
      .insert({ institucion_id: inst.id, nombre: carrera })
      .select("id")
      .single();
    if (e2 || !car) return fallo(e2?.message);

    const { error: e3 } = await supabase.from("procesos").insert({
      carrera_id: car.id,
      nombre: `Autoevaluación ${anio}`,
      anio,
    });
    if (e3) return fallo(e3.message);

    router.refresh();

    function fallo(m?: string) {
      setError(m ?? "Ocurrió un error.");
      setCargando(false);
    }
  }

  return (
    <div className="mx-auto mt-10 max-w-md rounded-xl border border-black/10 bg-white p-8">
      <h1 className="text-lg font-medium">Crea tu proceso de autoevaluación</h1>
      <p className="mt-1 text-sm text-neutral-500">
        Es el contenedor de todo el trabajo: pautas, evidencias, encuestas y
        mejora.
      </p>

      <form onSubmit={crear} className="mt-5 space-y-3">
        <input
          type="text"
          placeholder="Institución (universidad)"
          value={institucion}
          onChange={(e) => setInstitucion(e.target.value)}
          required
          className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
        />
        <input
          type="text"
          placeholder="Nombre de la carrera"
          value={carrera}
          onChange={(e) => setCarrera(e.target.value)}
          required
          className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
        />
        <input
          type="number"
          value={anio}
          onChange={(e) => setAnio(Number(e.target.value))}
          required
          className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
        />
        <button
          type="submit"
          disabled={cargando}
          className="w-full rounded-lg bg-marca-600 px-3 py-2 text-sm font-medium text-white hover:bg-marca-800 disabled:opacity-60"
        >
          {cargando ? "Creando…" : "Crear proceso"}
        </button>
      </form>

      {error && <p className="mt-3 text-sm text-mayor">{error}</p>}
    </div>
  );
}
