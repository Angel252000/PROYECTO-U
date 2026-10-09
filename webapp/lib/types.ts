// Tipos que reflejan las tablas y vistas de la base de datos SINAES

export type Categoria = "A" | "B" | "C" | "D";

export type Grado =
  | "no_evaluada"
  | "conforme"
  | "no_conformidad_menor"
  | "no_conformidad_mayor";

export type Semaforo = "verde" | "amarillo" | "rojo";

export interface Dimension {
  id: number;
  codigo: string;
  nombre: string;
  orden: number;
}

export interface Pauta {
  id: number;
  dimension_id: number;
  codigo: string;
  nombre: string;
  descripcion: string | null;
  categoria: Categoria;
  orden: number;
}

// Fila de la vista vw_pauta_estado (pauta + su evaluación dentro de un proceso)
export interface PautaEstado {
  proceso_id: string;
  pauta_id: number;
  codigo: string;
  nombre: string;
  categoria: Categoria;
  dimension_id: number;
  grado: Grado;
  conformidad: number | null;
  argumentacion: string | null;
  num_evidencias: number;
  peso_max: number;
  puntaje_obtenido: number;
  semaforo: Semaforo;
}

// Fila de la vista vw_dashboard
export interface DashboardKPIs {
  proceso_id: string;
  total_pautas: number;
  pautas_evaluadas: number;
  puntaje_max: number;
  puntaje_obtenido: number;
  progreso_pct: number;
  en_verde: number;
  en_amarillo: number;
  en_rojo: number;
}

// Fila de la vista vw_dimension_scores
export interface DimensionScore {
  proceso_id: string;
  dimension_id: number;
  dimension_codigo: string;
  dimension_nombre: string;
  total_pautas: number;
  pautas_evaluadas: number;
  puntaje_max: number;
  puntaje_obtenido: number;
  porcentaje: number;
}

export interface Proceso {
  id: string;
  carrera_id: string;
  nombre: string;
  anio: number;
  estado: string;
  modelo: string;
}
