import type { Categoria, Grado, Semaforo } from "./types";

// Grados de conformidad oficiales del SINAES
export const GRADOS: {
  value: Grado;
  label: string;
  pct: number | null;
  color: string;
}[] = [
  { value: "conforme", label: "Conformidad", pct: 100, color: "#639922" },
  { value: "no_conformidad_menor", label: "No conformidad menor", pct: 50, color: "#BA7517" },
  { value: "no_conformidad_mayor", label: "No conformidad mayor", pct: 0, color: "#E24B4A" },
  { value: "no_evaluada", label: "Sin evaluar", pct: null, color: "#888780" },
];

export function gradoLabel(g: Grado): string {
  return GRADOS.find((x) => x.value === g)?.label ?? "Sin evaluar";
}

// Peso de la categoría para el puntaje (igual que peso_score() en la BD)
export const PESO_SCORE: Record<Categoria, number> = {
  A: 2.5,
  B: 2.0,
  C: 1.5,
  D: 1.0,
};

export const SEMAFORO_COLOR: Record<Semaforo, string> = {
  verde: "#639922",
  amarillo: "#BA7517",
  rojo: "#E24B4A",
};

// Color por % de conformidad (para barras de avance)
export function colorPorcentaje(pct: number): string {
  if (pct >= 70) return "#639922";
  if (pct >= 50) return "#BA7517";
  return "#E24B4A";
}
