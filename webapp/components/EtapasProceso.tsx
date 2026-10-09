const ETAPAS = [
  { key: "recoleccion", label: "Recolección" },
  { key: "autoevaluacion", label: "Autoevaluación" },
  { key: "evaluacion_externa", label: "Eval. externa" },
  { key: "mejora", label: "Mejora" },
  { key: "finalizado", label: "Resultado" },
];

export default function EtapasProceso({ estado }: { estado: string }) {
  const idxActual = Math.max(
    0,
    ETAPAS.findIndex((e) => e.key === estado),
  );

  return (
    <div className="mt-4 flex flex-wrap items-center gap-2 text-xs">
      {ETAPAS.map((e, i) => {
        const estadoEtapa =
          i < idxActual ? "hecha" : i === idxActual ? "activa" : "pendiente";
        return (
          <div key={e.key} className="flex items-center gap-2">
            <span
              className={
                estadoEtapa === "activa"
                  ? "rounded-full bg-marca-50 px-3 py-1 font-medium text-marca-800"
                  : estadoEtapa === "hecha"
                    ? "text-conforme"
                    : "text-neutral-400"
              }
            >
              {estadoEtapa === "hecha" ? "✓ " : ""}
              {e.label}
            </span>
            {i < ETAPAS.length - 1 && <span className="text-neutral-300">—</span>}
          </div>
        );
      })}
    </div>
  );
}
