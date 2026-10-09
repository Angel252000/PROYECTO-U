-- =====================================================================
-- SINAES · Plataforma de Autoevaluación y Acreditación
-- Migración 0001 · Extensiones, tipos (ENUM) y funciones base
-- =====================================================================
-- Esta migración no crea tablas: define los "tipos" reutilizables del
-- modelo SINAES 2025 y utilidades comunes (timestamps, pesos, mapeos).
-- Ejecutar PRIMERO. El resto de migraciones dependen de estos tipos.
-- =====================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "unaccent";    -- búsquedas sin tildes

-- ---------------------------------------------------------------------
-- ENUMS (catálogos cerrados del modelo)
-- ---------------------------------------------------------------------

-- Roles de usuario en la plataforma
do $$ begin
  create type rol_usuario as enum (
    'admin',           -- administrador técnico de la plataforma
    'director',        -- director / decano que supervisa el proceso
    'coordinador',     -- coordina la autoevaluación de una carrera
    'academico',       -- personal docente
    'administrativo',  -- personal administrativo
    'estudiante',
    'graduado',
    'empleador',
    'evaluador_par'    -- par evaluador externo (SINAES)
  );
exception when duplicate_object then null; end $$;

-- Estado del proceso de autoevaluación (flujo SINAES)
do $$ begin
  create type estado_proceso as enum (
    'recoleccion',         -- 1. Recolección de información y encuestas
    'autoevaluacion',      -- 2. Construcción del informe de autoevaluación
    'evaluacion_externa',  -- 3. Pares evaluadores
    'mejora',              -- 4. Compromiso de mejora y seguimiento
    'finalizado'           -- 5. Resultado (acreditación / diferido)
  );
exception when duplicate_object then null; end $$;

-- Categoría de la pauta (peso/impacto). A es la de mayor peso.
do $$ begin
  create type categoria_pauta as enum ('A', 'B', 'C', 'D');
exception when duplicate_object then null; end $$;

-- Tipo de fuente de información (modelo SINAES)
--   I   = Documentación institucional
--   II  = Análisis interno
--   III = Datos cuantitativos
--   IV  = Opinión de actores (cuestionarios)
do $$ begin
  create type tipo_fuente as enum ('I', 'II', 'III', 'IV');
exception when duplicate_object then null; end $$;

-- Grado de conformidad oficial del SINAES por pauta
do $$ begin
  create type grado_conformidad as enum (
    'no_evaluada',
    'conforme',
    'no_conformidad_menor',
    'no_conformidad_mayor'
  );
exception when duplicate_object then null; end $$;

-- Semáforo del bot auditor
do $$ begin
  create type estado_semaforo as enum ('verde', 'amarillo', 'rojo');
exception when duplicate_object then null; end $$;

-- Prioridad (gap analysis / plan de mejora)
do $$ begin
  create type nivel_prioridad as enum ('alta', 'media', 'baja');
exception when duplicate_object then null; end $$;

-- Poblaciones objetivo de los cuestionarios (Tipo IV)
do $$ begin
  create type poblacion_objetivo as enum (
    'estudiantes', 'graduados', 'empleadores', 'academicos', 'administrativos'
  );
exception when duplicate_object then null; end $$;

-- Tipos de pregunta para encuestas dinámicas
do $$ begin
  create type tipo_pregunta as enum (
    'likert',         -- escala 1-5 de acuerdo
    'escala',         -- escala numérica configurable
    'opcion_unica',
    'opcion_multiple',
    'si_no',
    'abierta'         -- texto libre
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type estado_cuestionario as enum ('borrador', 'publicado', 'cerrado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type estado_invitacion as enum (
    'pendiente', 'enviada', 'abierta', 'respondida', 'expirada'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_informe_externo as enum ('preliminar', 'final');
exception when duplicate_object then null; end $$;

do $$ begin
  create type estado_avance as enum (
    'pendiente', 'en_proceso', 'completada', 'vencida'
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- FUNCIONES BASE
-- ---------------------------------------------------------------------

-- Mantiene actualizado el campo updated_at en cada UPDATE
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Peso de la categoría para el cálculo de PUNTAJE (Score total)
-- A=2.5, B=2, C=1.5, D=1  (alineado al modelo de scoring del proyecto)
create or replace function peso_score(cat categoria_pauta)
returns numeric
language sql
immutable
as $$
  select case cat
    when 'A' then 2.5
    when 'B' then 2.0
    when 'C' then 1.5
    when 'D' then 1.0
  end;
$$;

-- Peso de la categoría para PRIORIZACIÓN (gap analysis)
-- A=4, B=3, C=2, D=1
create or replace function peso_prioridad(cat categoria_pauta)
returns int
language sql
immutable
as $$
  select case cat
    when 'A' then 4
    when 'B' then 3
    when 'C' then 2
    when 'D' then 1
  end;
$$;

-- Convierte el grado de conformidad oficial a un % numérico (0-100)
-- conforme=100, no_conformidad_menor=50, no_conformidad_mayor=0
create or replace function conformidad_a_pct(g grado_conformidad)
returns int
language sql
immutable
as $$
  select case g
    when 'conforme' then 100
    when 'no_conformidad_menor' then 50
    when 'no_conformidad_mayor' then 0
    else null
  end;
$$;
