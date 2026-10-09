-- =====================================================================
-- SINAES · Migración 0002 · Catálogo del MODELO + Procesos
-- =====================================================================
-- Aquí vive la "estructura oficial" del modelo SINAES (dimensiones,
-- pautas, fuentes sugeridas, subprocesos) y los contenedores de trabajo
-- (instituciones, carreras, procesos de autoevaluación).
--
-- IMPORTANTE: el contenido REAL (las 59 pautas, sus textos y categorías)
-- se carga después desde los Excel oficiales. El seed solo deja la
-- estructura y datos mínimos marcados como [PLACEHOLDER].
-- =====================================================================

-- ---------------------------------------------------------------------
-- INSTITUCIONES Y CARRERAS
-- ---------------------------------------------------------------------
create table if not exists instituciones (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  siglas      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists carreras (
  id              uuid primary key default gen_random_uuid(),
  institucion_id  uuid not null references instituciones(id) on delete cascade,
  nombre          text not null,
  grado_academico text,                 -- Bachillerato, Licenciatura, etc.
  sede            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- PROCESO DE AUTOEVALUACIÓN  (contenedor central de todo el trabajo)
-- ---------------------------------------------------------------------
-- Un proceso = un ciclo de autoevaluación de una carrera en un año.
-- TODO lo operativo (evaluaciones, evidencias, encuestas, mejora)
-- cuelga de un proceso → trazabilidad total.
create table if not exists procesos (
  id          uuid primary key default gen_random_uuid(),
  carrera_id  uuid not null references carreras(id) on delete cascade,
  nombre      text not null,                       -- "Autoevaluación 2025"
  anio        int  not null,
  estado      estado_proceso not null default 'recoleccion',
  modelo      text not null default 'Grado 2025',  -- versión del modelo SINAES
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- DIMENSIONES  (componentes mayores del modelo)
-- ---------------------------------------------------------------------
create table if not exists dimensiones (
  id          bigint generated always as identity primary key,
  codigo      text not null unique,        -- "D1", "D2"...
  nombre      text not null,
  descripcion text,
  orden       int not null default 0
);

-- ---------------------------------------------------------------------
-- PAUTAS  (las 59 pautas evaluables)
-- ---------------------------------------------------------------------
create table if not exists pautas (
  id           bigint generated always as identity primary key,
  dimension_id bigint not null references dimensiones(id) on delete restrict,
  codigo       text not null unique,        -- "1.1", "P12"...
  nombre       text not null,               -- enunciado corto
  descripcion  text,                         -- texto completo de la pauta
  categoria    categoria_pauta not null,
  orden        int not null default 0
);
create index if not exists idx_pautas_dimension on pautas(dimension_id);

-- ---------------------------------------------------------------------
-- FUENTES sugeridas por pauta  (catálogo del modelo, Tipo I-IV)
-- ---------------------------------------------------------------------
create table if not exists fuentes (
  id        bigint generated always as identity primary key,
  pauta_id  bigint not null references pautas(id) on delete cascade,
  tipo      tipo_fuente not null,
  nombre    text not null,
  orden     int not null default 0
);
create index if not exists idx_fuentes_pauta on fuentes(pauta_id);

-- ---------------------------------------------------------------------
-- SUBPROCESOS  (la "Guía Inteligente": pasos para trabajar cada pauta)
-- ---------------------------------------------------------------------
create table if not exists subprocesos (
  id          bigint generated always as identity primary key,
  pauta_id    bigint not null references pautas(id) on delete cascade,
  descripcion text not null,
  orden       int not null default 0
);
create index if not exists idx_subprocesos_pauta on subprocesos(pauta_id);

-- ---------------------------------------------------------------------
-- Triggers updated_at
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['instituciones','carreras','procesos'] loop
    execute format(
      'drop trigger if exists trg_%1$s_updated on %1$s;
       create trigger trg_%1$s_updated before update on %1$s
       for each row execute function set_updated_at();', t);
  end loop;
end $$;
