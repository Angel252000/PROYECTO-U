-- =====================================================================
-- SINAES · INSTALADOR COMPLETO (TODO EN UNO)
-- =====================================================================
-- Pega TODO este archivo en el SQL Editor de Supabase y pulsa Run.
-- Incluye: esquema (8 migraciones) + datos reales (6 dim, 59 pautas, 137 fuentes).
-- Generado: 2026-06-17 15:55
-- =====================================================================


-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0001_extensiones_y_tipos.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
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

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0002_modelo_catalogo.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
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

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0003_usuarios_roles.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- =====================================================================
-- SINAES · Migración 0003 · Usuarios, perfiles y roles por proceso
-- =====================================================================
-- Supabase ya provee la tabla auth.users (login/contraseña/OAuth).
-- Aquí extendemos con un perfil público y asignamos roles POR PROCESO,
-- porque una persona puede ser coordinadora del proceso A y solo
-- lectora del proceso B.
-- =====================================================================

-- Perfil público 1:1 con auth.users
create table if not exists profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  nombre       text,
  email        text,
  telefono     text,
  es_admin     boolean not null default false,  -- admin global de plataforma
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Membresía: qué rol tiene cada persona dentro de cada proceso
create table if not exists miembros_proceso (
  id          uuid primary key default gen_random_uuid(),
  proceso_id  uuid not null references procesos(id) on delete cascade,
  profile_id  uuid not null references profiles(id) on delete cascade,
  rol         rol_usuario not null,
  created_at  timestamptz not null default now(),
  unique (proceso_id, profile_id, rol)
);
create index if not exists idx_miembros_proceso on miembros_proceso(proceso_id);
create index if not exists idx_miembros_profile on miembros_proceso(profile_id);

-- ---------------------------------------------------------------------
-- Crear automáticamente el perfil cuando se registra un usuario nuevo
-- ---------------------------------------------------------------------
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nombre, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', new.email),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------------------------------------------------------------------
-- Helpers de autorización (se usan en las políticas RLS, migración 0008)
-- ---------------------------------------------------------------------

-- ¿El usuario actual es admin global?
create or replace function es_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce((select es_admin from profiles where id = auth.uid()), false);
$$;

-- ¿El usuario actual es miembro del proceso (cualquier rol)?
create or replace function es_miembro(p_proceso uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from miembros_proceso
    where proceso_id = p_proceso and profile_id = auth.uid()
  ) or es_admin();
$$;

-- ¿El usuario actual puede EDITAR el proceso? (coordinador/director/admin)
create or replace function puede_editar(p_proceso uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from miembros_proceso
    where proceso_id = p_proceso
      and profile_id = auth.uid()
      and rol in ('coordinador', 'director')
  ) or es_admin();
$$;

drop trigger if exists trg_profiles_updated on profiles;
create trigger trg_profiles_updated before update on profiles
  for each row execute function set_updated_at();

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0004_autoevaluacion.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- =====================================================================
-- SINAES · Migración 0004 · Autoevaluación, evidencias, auditoría, mejora
-- =====================================================================
-- El corazón operativo: por cada PROCESO y cada PAUTA se registran la
-- evaluación, las evidencias (archivos), el resultado del bot auditor y
-- el plan/compromiso de mejora.
-- =====================================================================

-- ---------------------------------------------------------------------
-- EVALUACIONES  (valoración de cada pauta dentro de un proceso)
-- ---------------------------------------------------------------------
create table if not exists evaluaciones (
  id            uuid primary key default gen_random_uuid(),
  proceso_id    uuid   not null references procesos(id) on delete cascade,
  pauta_id      bigint not null references pautas(id) on delete restrict,
  grado         grado_conformidad not null default 'no_evaluada',
  conformidad   int,                          -- % 0-100 (derivado o manual)
  argumentacion text,
  evaluado_por  uuid references profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (proceso_id, pauta_id),
  constraint chk_conformidad_rango
    check (conformidad is null or (conformidad between 0 and 100))
);
create index if not exists idx_eval_proceso on evaluaciones(proceso_id);

-- Si se fija el grado y no el %, derivar el % automáticamente
create or replace function sync_conformidad()
returns trigger
language plpgsql
as $$
begin
  if new.conformidad is null and new.grado is not null then
    new.conformidad := conformidad_a_pct(new.grado);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_eval_sync on evaluaciones;
create trigger trg_eval_sync before insert or update on evaluaciones
  for each row execute function sync_conformidad();

-- ---------------------------------------------------------------------
-- EVIDENCIAS  (archivos subidos, clasificados por tipo de fuente)
-- ---------------------------------------------------------------------
-- El archivo físico vive en Supabase Storage (bucket 'evidencias').
-- Aquí guardamos la metadata + la ruta dentro del bucket.
create table if not exists evidencias (
  id             uuid primary key default gen_random_uuid(),
  proceso_id     uuid   not null references procesos(id) on delete cascade,
  pauta_id       bigint not null references pautas(id) on delete cascade,
  tipo           tipo_fuente,                  -- I / II / III / IV
  nombre_archivo text not null,
  storage_path   text not null,                -- ruta en el bucket
  mime_type      text,
  tamano_bytes   bigint,
  descripcion    text,
  subido_por     uuid references profiles(id) on delete set null,
  created_at     timestamptz not null default now()
);
create index if not exists idx_evid_proceso_pauta on evidencias(proceso_id, pauta_id);

-- ---------------------------------------------------------------------
-- AUDITORÍAS  (salida del bot auditor: semáforo + hallazgos)
-- ---------------------------------------------------------------------
create table if not exists auditorias (
  id                  uuid primary key default gen_random_uuid(),
  proceso_id          uuid   not null references procesos(id) on delete cascade,
  pauta_id            bigint not null references pautas(id) on delete cascade,
  estado              estado_semaforo not null,
  hallazgos           text,
  acciones_correctivas text,
  generada_por_bot    boolean not null default true,
  created_at          timestamptz not null default now(),
  unique (proceso_id, pauta_id)
);

-- ---------------------------------------------------------------------
-- PLAN DE MEJORA  (Compromiso de mejora + Informe de logros, Formato 8)
-- ---------------------------------------------------------------------
create table if not exists plan_mejora (
  id              uuid primary key default gen_random_uuid(),
  proceso_id      uuid   not null references procesos(id) on delete cascade,
  pauta_id        bigint references pautas(id) on delete set null,
  debilidad       text,                         -- debilidad detectada
  actividad       text not null,                -- acción de mejora
  indicador       text,                         -- indicador de logro
  responsable     text,
  plazo           date,
  recursos        text,
  prioridad       nivel_prioridad not null default 'media',
  estado          estado_avance not null default 'pendiente',
  porcentaje_avance int not null default 0
                    check (porcentaje_avance between 0 and 100),
  evidencia_logro text,                          -- informe de logros
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists idx_mejora_proceso on plan_mejora(proceso_id);

-- ---------------------------------------------------------------------
-- Triggers updated_at
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['evaluaciones','plan_mejora'] loop
    execute format(
      'drop trigger if exists trg_%1$s_updated on %1$s;
       create trigger trg_%1$s_updated before update on %1$s
       for each row execute function set_updated_at();', t);
  end loop;
end $$;

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0005_encuestas.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- =====================================================================
-- SINAES · Migración 0005 · Módulo de Encuestas (Fuente Tipo IV)
-- =====================================================================
-- Cuestionarios dinámicos por población (estudiantes, graduados,
-- empleadores, académicos, administrativos). Cada pregunta puede ligarse
-- a una pauta/dimensión para alimentar automáticamente el análisis.
-- =====================================================================

-- ---------------------------------------------------------------------
-- CUESTIONARIOS
-- ---------------------------------------------------------------------
create table if not exists cuestionarios (
  id          uuid primary key default gen_random_uuid(),
  proceso_id  uuid not null references procesos(id) on delete cascade,
  poblacion   poblacion_objetivo not null,
  titulo      text not null,
  descripcion text,
  estado      estado_cuestionario not null default 'borrador',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_cuest_proceso on cuestionarios(proceso_id);

-- ---------------------------------------------------------------------
-- PREGUNTAS
-- ---------------------------------------------------------------------
create table if not exists preguntas (
  id              uuid primary key default gen_random_uuid(),
  cuestionario_id uuid not null references cuestionarios(id) on delete cascade,
  texto           text not null,
  tipo            tipo_pregunta not null default 'likert',
  obligatoria     boolean not null default true,
  orden           int not null default 0,
  -- Vínculo opcional al modelo para análisis automático:
  pauta_id        bigint references pautas(id) on delete set null,
  dimension_id    bigint references dimensiones(id) on delete set null,
  created_at      timestamptz not null default now()
);
create index if not exists idx_preg_cuest on preguntas(cuestionario_id);

-- Opciones (para opcion_unica / opcion_multiple / escala personalizada)
create table if not exists opciones_pregunta (
  id          uuid primary key default gen_random_uuid(),
  pregunta_id uuid not null references preguntas(id) on delete cascade,
  texto       text not null,
  valor       numeric,            -- valor numérico para análisis
  orden       int not null default 0
);
create index if not exists idx_opc_pregunta on opciones_pregunta(pregunta_id);

-- ---------------------------------------------------------------------
-- INVITACIONES  (a quién se le envía la encuesta; token anónimo)
-- ---------------------------------------------------------------------
create table if not exists invitaciones (
  id              uuid primary key default gen_random_uuid(),
  cuestionario_id uuid not null references cuestionarios(id) on delete cascade,
  email           text,
  nombre          text,
  token           text not null unique default encode(gen_random_bytes(16), 'hex'),
  estado          estado_invitacion not null default 'pendiente',
  enviada_at      timestamptz,
  respondida_at   timestamptz,
  created_at      timestamptz not null default now()
);
create index if not exists idx_inv_cuest on invitaciones(cuestionario_id);
create index if not exists idx_inv_token on invitaciones(token);

-- ---------------------------------------------------------------------
-- RESPUESTAS  (una fila por pregunta respondida)
-- ---------------------------------------------------------------------
create table if not exists respuestas (
  id             uuid primary key default gen_random_uuid(),
  invitacion_id  uuid not null references invitaciones(id) on delete cascade,
  pregunta_id    uuid not null references preguntas(id) on delete cascade,
  opcion_id      uuid references opciones_pregunta(id) on delete set null,
  valor_numerico numeric,        -- para likert/escala (1-5)
  valor_texto    text,           -- para preguntas abiertas
  created_at     timestamptz not null default now()
);
create index if not exists idx_resp_invitacion on respuestas(invitacion_id);
create index if not exists idx_resp_pregunta on respuestas(pregunta_id);

-- ---------------------------------------------------------------------
-- Triggers updated_at
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['cuestionarios'] loop
    execute format(
      'drop trigger if exists trg_%1$s_updated on %1$s;
       create trigger trg_%1$s_updated before update on %1$s
       for each row execute function set_updated_at();', t);
  end loop;
end $$;

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0006_evaluacion_externa.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- =====================================================================
-- SINAES · Migración 0006 · Evaluación externa (pares evaluadores)
-- =====================================================================
-- Los pares evaluadores revisan el informe + evidencias y emiten un
-- informe preliminar y uno final (Formato 2). Cada par valora pautas.
-- =====================================================================

create table if not exists informes_externos (
  id           uuid primary key default gen_random_uuid(),
  proceso_id   uuid not null references procesos(id) on delete cascade,
  tipo         tipo_informe_externo not null,
  par_id       uuid references profiles(id) on delete set null,  -- evaluador_par
  resumen      text,
  recomendacion text,           -- acreditación / diferido / no acreditación
  publicado    boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_infext_proceso on informes_externos(proceso_id);

-- Valoración de cada pauta por el par evaluador
create table if not exists valoraciones_pares (
  id                uuid primary key default gen_random_uuid(),
  informe_id        uuid   not null references informes_externos(id) on delete cascade,
  pauta_id          bigint not null references pautas(id) on delete cascade,
  grado             grado_conformidad not null default 'no_evaluada',
  comentario        text,
  coincide_con_auto boolean,    -- ¿coincide con la autoevaluación?
  created_at        timestamptz not null default now(),
  unique (informe_id, pauta_id)
);
create index if not exists idx_valpar_informe on valoraciones_pares(informe_id);

drop trigger if exists trg_informes_externos_updated on informes_externos;
create trigger trg_informes_externos_updated before update on informes_externos
  for each row execute function set_updated_at();

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0007_funciones_vistas.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- =====================================================================
-- SINAES · Migración 0007 · Motores: Scoring, Dashboard, Gap, Bot Auditor
-- =====================================================================
-- Aquí vive la LÓGICA del proyecto original (scoring, gap analysis, bot
-- auditor) reescrita en PostgreSQL como vistas y funciones, para que el
-- cálculo viva junto a los datos y sea reutilizable desde cualquier
-- cliente (web, IA, exportación).
-- =====================================================================

-- ---------------------------------------------------------------------
-- VISTA: estado de cada pauta dentro de un proceso
-- (evaluación + nº de evidencias + semáforo del bot auditor)
-- ---------------------------------------------------------------------
create or replace view vw_pauta_estado with (security_invoker = true) as
select
  pr.id                                    as proceso_id,
  p.id                                     as pauta_id,
  p.codigo,
  p.nombre,
  p.categoria,
  p.dimension_id,
  coalesce(e.grado, 'no_evaluada')         as grado,
  e.conformidad,
  e.argumentacion,
  (select count(*) from evidencias ev
     where ev.proceso_id = pr.id and ev.pauta_id = p.id) as num_evidencias,
  peso_score(p.categoria)                  as peso_max,
  peso_score(p.categoria) * coalesce(e.conformidad, 0) / 100.0 as puntaje_obtenido,
  -- Semáforo (misma regla del bot auditor original):
  case
    when e.conformidad is null then 'rojo'
    when (select count(*) from evidencias ev
            where ev.proceso_id = pr.id and ev.pauta_id = p.id) = 0 then 'rojo'
    when e.argumentacion is null or length(e.argumentacion) < 10 then 'amarillo'
    when e.conformidad = 100 then 'verde'
    else 'amarillo'
  end::estado_semaforo                     as semaforo
from procesos pr
cross join pautas p
left join evaluaciones e
  on e.proceso_id = pr.id and e.pauta_id = p.id;

-- ---------------------------------------------------------------------
-- VISTA: puntaje por dimensión (para el radar chart)
-- ---------------------------------------------------------------------
create or replace view vw_dimension_scores with (security_invoker = true) as
select
   pe.proceso_id,
  d.id                          as dimension_id,
  d.codigo                      as dimension_codigo,
  d.nombre                      as dimension_nombre,
  count(*)                      as total_pautas,
  count(*) filter (where pe.grado <> 'no_evaluada') as pautas_evaluadas,
  sum(pe.peso_max)              as puntaje_max,
  sum(pe.puntaje_obtenido)      as puntaje_obtenido,
  round(100.0 * sum(pe.puntaje_obtenido) / nullif(sum(pe.peso_max), 0), 1) as porcentaje
from vw_pauta_estado pe
join dimensiones d on d.id = pe.dimension_id
group by pe.proceso_id, d.id, d.codigo, d.nombre, d.orden
order by d.orden;

-- ---------------------------------------------------------------------
-- VISTA: KPIs globales por proceso (tarjetas del dashboard)
-- ---------------------------------------------------------------------
create or replace view vw_dashboard with (security_invoker = true) as
select
  pe.proceso_id,
  count(*)                                          as total_pautas,
  count(*) filter (where pe.grado <> 'no_evaluada') as pautas_evaluadas,
  sum(pe.peso_max)                                  as puntaje_max,
  round(sum(pe.puntaje_obtenido), 2)                as puntaje_obtenido,
  round(100.0 * sum(pe.puntaje_obtenido) / nullif(sum(pe.peso_max), 0), 1) as progreso_pct,
  count(*) filter (where pe.semaforo = 'verde')     as en_verde,
  count(*) filter (where pe.semaforo = 'amarillo')  as en_amarillo,
  count(*) filter (where pe.semaforo = 'rojo')      as en_rojo
from vw_pauta_estado pe
group by pe.proceso_id;

-- ---------------------------------------------------------------------
-- FUNCIÓN: Gap Analysis  (prioriza pautas no conformes por impacto)
--   priority_score = brecha(%) * peso_prioridad(categoría)
-- ---------------------------------------------------------------------
create or replace function gap_analysis(p_proceso uuid)
returns table (
  pauta_id       bigint,
  codigo         text,
  nombre         text,
  categoria      categoria_pauta,
  brecha         int,
  priority_score int
)
language sql
stable
as $$
  select
    pe.pauta_id,
    pe.codigo,
    pe.nombre,
    pe.categoria,
    (100 - coalesce(pe.conformidad, 0))                       as brecha,
    (100 - coalesce(pe.conformidad, 0)) * peso_prioridad(pe.categoria) as priority_score
  from vw_pauta_estado pe
  where pe.proceso_id = p_proceso
    and coalesce(pe.conformidad, 0) < 100
  order by priority_score desc;
$$;

-- ---------------------------------------------------------------------
-- FUNCIÓN: Bot Auditor  (recalcula y persiste el semáforo + hallazgos)
-- Devuelve las filas generadas; además las guarda en 'auditorias'.
-- ---------------------------------------------------------------------
create or replace function recalcular_auditoria(p_proceso uuid)
returns setof auditorias
language plpgsql
as $$
begin
  insert into auditorias (proceso_id, pauta_id, estado, hallazgos, generada_por_bot)
  select
    pe.proceso_id,
    pe.pauta_id,
    pe.semaforo,
    trim(both ' |' from concat_ws(' | ',
      case when pe.num_evidencias = 0 then 'Falta evidencia documental' end,
      case when pe.argumentacion is null or length(pe.argumentacion) < 10
           then 'Argumentación insuficiente' end,
      case when pe.grado = 'no_evaluada' then 'Pauta sin evaluar' end
    )),
    true
  from vw_pauta_estado pe
  where pe.proceso_id = p_proceso
  on conflict (proceso_id, pauta_id) do update
    set estado    = excluded.estado,
        hallazgos = excluded.hallazgos,
        generada_por_bot = true,
        created_at = now();

  return query select * from auditorias where proceso_id = p_proceso;
end;
$$;

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ migrations/0008_rls.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- =====================================================================
-- SINAES · Migración 0008 · Seguridad por fila (Row Level Security)
-- =====================================================================
-- Regla general:
--   · Catálogo del modelo (dimensiones, pautas...): lo lee cualquier
--     usuario autenticado; solo lo edita un admin.
--   · Datos de un proceso (evaluaciones, evidencias, encuestas...): solo
--     los ven los MIEMBROS del proceso; solo los editan coordinador/
--     director/admin (función puede_editar()).
--   · El responder encuestas anónimas (con token) se hará vía Edge
--     Function con service_role en la fase de Encuestas; por eso aquí
--     las tablas de encuesta quedan restringidas a miembros.
--
-- NOTA: instituciones/carreras quedan abiertas a usuarios autenticados
-- para facilitar el onboarding; conviene endurecerlas más adelante.
-- =====================================================================

-- Al crear un proceso, el creador queda como coordinador automáticamente
create or replace function handle_new_proceso()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is not null then
    insert into miembros_proceso (proceso_id, profile_id, rol)
    values (new.id, auth.uid(), 'coordinador')
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_on_proceso_created on procesos;
create trigger trg_on_proceso_created
  after insert on procesos
  for each row execute function handle_new_proceso();

-- ---------------------------------------------------------------------
-- Habilitar RLS en todas las tablas
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'instituciones','carreras','procesos','dimensiones','pautas','fuentes',
    'subprocesos','profiles','miembros_proceso','evaluaciones','evidencias',
    'auditorias','plan_mejora','cuestionarios','preguntas','opciones_pregunta',
    'invitaciones','respuestas','informes_externos','valoraciones_pares'
  ] loop
    execute format('alter table %I enable row level security;', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PROFILES
-- ---------------------------------------------------------------------
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select to authenticated
  using (id = auth.uid() or es_admin());

drop policy if exists profiles_update on profiles;
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid() or es_admin())
  with check (id = auth.uid() or es_admin());

-- ---------------------------------------------------------------------
-- CATÁLOGO DEL MODELO  (lectura para todos; escritura solo admin)
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['dimensiones','pautas','fuentes','subprocesos'] loop
    execute format('drop policy if exists %1$s_select on %1$s;', t);
    execute format(
      'create policy %1$s_select on %1$s for select to authenticated using (true);', t);
    execute format('drop policy if exists %1$s_write on %1$s;', t);
    execute format(
      'create policy %1$s_write on %1$s for all to authenticated
       using (es_admin()) with check (es_admin());', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- INSTITUCIONES / CARRERAS  (autenticados; endurecer luego)
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['instituciones','carreras'] loop
    execute format('drop policy if exists %1$s_all on %1$s;', t);
    execute format(
      'create policy %1$s_all on %1$s for all to authenticated
       using (true) with check (true);', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PROCESOS
-- ---------------------------------------------------------------------
drop policy if exists procesos_select on procesos;
create policy procesos_select on procesos for select to authenticated
  using (es_miembro(id));

drop policy if exists procesos_insert on procesos;
create policy procesos_insert on procesos for insert to authenticated
  with check (true);   -- el trigger asigna al creador como coordinador

drop policy if exists procesos_modify on procesos;
create policy procesos_modify on procesos for update to authenticated
  using (puede_editar(id)) with check (puede_editar(id));

drop policy if exists procesos_delete on procesos;
create policy procesos_delete on procesos for delete to authenticated
  using (puede_editar(id));

-- ---------------------------------------------------------------------
-- MIEMBROS DEL PROCESO
-- ---------------------------------------------------------------------
drop policy if exists miembros_select on miembros_proceso;
create policy miembros_select on miembros_proceso for select to authenticated
  using (es_miembro(proceso_id));

drop policy if exists miembros_write on miembros_proceso;
create policy miembros_write on miembros_proceso for all to authenticated
  using (puede_editar(proceso_id)) with check (puede_editar(proceso_id));

-- ---------------------------------------------------------------------
-- TABLAS CON proceso_id DIRECTO
--   (evaluaciones, evidencias, auditorias, plan_mejora, cuestionarios,
--    informes_externos)
--   lectura: miembros · escritura: editores
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'evaluaciones','evidencias','auditorias','plan_mejora',
    'cuestionarios','informes_externos'
  ] loop
    execute format('drop policy if exists %1$s_select on %1$s;', t);
    execute format(
      'create policy %1$s_select on %1$s for select to authenticated
       using (es_miembro(proceso_id));', t);
    execute format('drop policy if exists %1$s_write on %1$s;', t);
    execute format(
      'create policy %1$s_write on %1$s for all to authenticated
       using (puede_editar(proceso_id)) with check (puede_editar(proceso_id));', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- TABLAS HIJAS (proceso_id indirecto vía la tabla padre)
-- ---------------------------------------------------------------------

-- preguntas → cuestionarios
drop policy if exists preguntas_select on preguntas;
create policy preguntas_select on preguntas for select to authenticated
  using (es_miembro((select proceso_id from cuestionarios c where c.id = cuestionario_id)));
drop policy if exists preguntas_write on preguntas;
create policy preguntas_write on preguntas for all to authenticated
  using (puede_editar((select proceso_id from cuestionarios c where c.id = cuestionario_id)))
  with check (puede_editar((select proceso_id from cuestionarios c where c.id = cuestionario_id)));

-- opciones_pregunta → preguntas → cuestionarios
drop policy if exists opciones_select on opciones_pregunta;
create policy opciones_select on opciones_pregunta for select to authenticated
  using (es_miembro((select c.proceso_id from preguntas p
                     join cuestionarios c on c.id = p.cuestionario_id
                     where p.id = pregunta_id)));
drop policy if exists opciones_write on opciones_pregunta;
create policy opciones_write on opciones_pregunta for all to authenticated
  using (puede_editar((select c.proceso_id from preguntas p
                       join cuestionarios c on c.id = p.cuestionario_id
                       where p.id = pregunta_id)))
  with check (puede_editar((select c.proceso_id from preguntas p
                            join cuestionarios c on c.id = p.cuestionario_id
                            where p.id = pregunta_id)));

-- invitaciones → cuestionarios
drop policy if exists invitaciones_select on invitaciones;
create policy invitaciones_select on invitaciones for select to authenticated
  using (es_miembro((select proceso_id from cuestionarios c where c.id = cuestionario_id)));
drop policy if exists invitaciones_write on invitaciones;
create policy invitaciones_write on invitaciones for all to authenticated
  using (puede_editar((select proceso_id from cuestionarios c where c.id = cuestionario_id)))
  with check (puede_editar((select proceso_id from cuestionarios c where c.id = cuestionario_id)));

-- respuestas → invitaciones → cuestionarios
drop policy if exists respuestas_select on respuestas;
create policy respuestas_select on respuestas for select to authenticated
  using (es_miembro((select c.proceso_id from invitaciones i
                     join cuestionarios c on c.id = i.cuestionario_id
                     where i.id = invitacion_id)));
-- (las respuestas anónimas con token se insertarán vía Edge Function)

-- valoraciones_pares → informes_externos
drop policy if exists valoraciones_select on valoraciones_pares;
create policy valoraciones_select on valoraciones_pares for select to authenticated
  using (es_miembro((select proceso_id from informes_externos i where i.id = informe_id)));
drop policy if exists valoraciones_write on valoraciones_pares;
create policy valoraciones_write on valoraciones_pares for all to authenticated
  using (puede_editar((select proceso_id from informes_externos i where i.id = informe_id)))
  with check (puede_editar((select proceso_id from informes_externos i where i.id = informe_id)));

-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- ▶ seed.sql
-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
-- =====================================================================
-- SINAES · SEED del MODELO DE GRADO 2025  (DATOS OFICIALES REALES)
-- =====================================================================
-- GENERADO automáticamente desde el 'Formato 1' oficial del SINAES.
-- NO editar a mano. Regenerar con:
--   ./.venv-import/bin/python supabase/import/generar_seed.py
-- Contenido: 6 dimensiones, 59 pautas, 137 fuentes.
-- =====================================================================

-- DIMENSIONES (6)
insert into dimensiones (codigo, nombre, orden) values
  ('D1', 'Plan de estudios', 1),
  ('D2', 'Proceso educativo', 2),
  ('D3', 'Estudiantes y personas graduadas', 3),
  ('D4', 'Personal académico, administrativo, técnico y de apoyo', 4),
  ('D5', 'Recursos y servicios de apoyo', 5),
  ('D6', 'Gestión de la carrera', 6)
on conflict (codigo) do update set nombre = excluded.nombre, orden = excluded.orden;

-- PAUTAS (59)
insert into pautas (dimension_id, codigo, nombre, categoria, orden) values
  ((select id from dimensiones where codigo = 'D1'), '1', 'Los programas de los cursos de la malla curricular vigente son coherentes con el perfil académico profesional de la carrera (sustentado en los referentes nacionales e internacionales actuales, el desarrollo y las tendencias de la disciplina o de la profesión).', 'A'::categoria_pauta, 1),
  ((select id from dimensiones where codigo = 'D1'), '2', 'El perfil o requisitos de ingreso requeridos son coherentes con los resultados de aprendizaje/objetivos de aprendizaje esperados para los grados.', 'A'::categoria_pauta, 2),
  ((select id from dimensiones where codigo = 'D1'), '3', 'Las estrategias y metodologías de enseñanza y de evaluación para los aprendizajes son pertinentes para lograr el perfil académico profesional.', 'A'::categoria_pauta, 3),
  ((select id from dimensiones where codigo = 'D1'), '4', 'La dedicación académica estudiantil requerida en cada una de las asignaturas es suficiente para lograr los aprendizajes previstos.', 'A'::categoria_pauta, 4),
  ((select id from dimensiones where codigo = 'D1'), '5', 'Las actividades de aprendizaje son pertinentes para lograr los resultados/objetivos de aprendizaje de los cursos.', 'A'::categoria_pauta, 5),
  ((select id from dimensiones where codigo = 'D1'), '6', 'La carrera cuenta con procedimientos eficaces de revisión y actualización periódica del plan de estudios al menos cada cuatro años, donde incorpora la participación del personal académico, estudiantado, personas graduadas y empleadores.', 'A'::categoria_pauta, 6),
  ((select id from dimensiones where codigo = 'D1'), '7', 'La carrera desarrolla actividades académicas extracurriculares pertinentes para la formación que imparte y el desarrollo de habilidades para la vida.', 'D'::categoria_pauta, 7),
  ((select id from dimensiones where codigo = 'D1'), '8', 'La carrera en sus estrategias pedagógicas incorpora recursos didácticos idóneos que le permiten al estudiantado apropiarse de contenidos disciplinares relevantes y actualizados en una segunda lengua.', 'B'::categoria_pauta, 8),
  ((select id from dimensiones where codigo = 'D1'), '9', 'La carrera promueve con eficacia el desarrollo de competencias digitales tales como:
*Gestión de la información (por ejemplo, cómo y dónde buscar recursos, cómo gestionar, rastrear y organizar información en una biblioteca, cómo identificar la validez y confiabilidad de las fuentes).
*Comunicación digital (por ejemplo: familiarización con la comunicación asincrónica).
*Trabajo colaborativo virtual (por ejemplo: edición colaborativa de archivos en tiempo real).
*Visión digital estratégica (por ejemplo: cómo las herramientas digitales colaboran en la mejora del trabajo cotidiano).
*Liderazgo digital (por ejemplo: gestionar la identidad virtual, a partir de la creación o distribución de contenido).
*Seguridad digital y resolución de problemas técnicos (por ejemplo, identificar, evitar o corregir riesgos o problemas en el terreno digital).
*Ofimática y edición de contenidos (por ejemplo: nociones de software).', 'B'::categoria_pauta, 9),
  ((select id from dimensiones where codigo = 'D1'), '10', 'El plan de estudios de la carrera promueve elementos pertinentes para el desarrollo de competencias de indagación y razonamiento científico en el estudiantado.', 'A'::categoria_pauta, 10),
  ((select id from dimensiones where codigo = 'D1'), '11', 'La carrera cuenta con políticas, recursos y estrategias para promover en el personal académico el desarrollo de proyectos, actividades y acciones de investigación, extensión, innovación, diseño y producción artística, según corresponda.', 'A'::categoria_pauta, 11),
  ((select id from dimensiones where codigo = 'D1'), '12', 'La investigación educativa y científica, la extensión, la innovación, el diseño y la producción artística, según corresponda, mejoran e impulsan en forma eficaz el pensamiento crítico, creativo, innovador y científico en el personal académico y el estudiantado.', 'B'::categoria_pauta, 12),
  ((select id from dimensiones where codigo = 'D2'), '13', 'Las estrategias de mediación pedagógica aplicadas en la carrera son coherentes con la naturaleza de la disciplina, el modelo educativo de la institución y la modalidad de los cursos.', 'A'::categoria_pauta, 13),
  ((select id from dimensiones where codigo = 'D2'), '14', 'La carrera implementa una mediación pedagógica oportuna para desarrollar las capacidades definidas en el perfil académico profesional.', 'B'::categoria_pauta, 14),
  ((select id from dimensiones where codigo = 'D2'), '15', 'La carrera cuenta con procedimientos eficaces que garanticen la asesoría y supervisión al estudiantado en las diferentes modalidades de graduación y durante su práctica profesional.', 'D'::categoria_pauta, 15),
  ((select id from dimensiones where codigo = 'D2'), '16', 'Las actividades de evaluación para los aprendizajes promueven la equidad, mediante estrategias alternativas para todo el estudiantado.', 'A'::categoria_pauta, 16),
  ((select id from dimensiones where codigo = 'D2'), '17', 'La carrera le brinda a cada estudiante realimentación con eficacia sobre los resultados de sus evaluaciones para el aprendizaje.', 'B'::categoria_pauta, 17),
  ((select id from dimensiones where codigo = 'D2'), '18', 'Los resultados de la evaluación para los aprendizajes se utilizan de manera eficaz en el mejoramiento de los procesos pedagógicos.', 'B'::categoria_pauta, 18),
  ((select id from dimensiones where codigo = 'D2'), '19', 'Los recursos didácticos (físicos y virtuales) que utiliza la carrera para el desarrollo de las actividades de aprendizaje son pertinentes, de acuerdo con la modalidad en que se imparte.', 'B'::categoria_pauta, 19),
  ((select id from dimensiones where codigo = 'D2'), '20', 'Las técnicas e instrumentos de evaluación para los aprendizajes son coherentes con los objetivos del aprendizaje y las estrategias de mediación pedagógica de los cursos.', 'B'::categoria_pauta, 20),
  ((select id from dimensiones where codigo = 'D2'), '21', 'La carrera cuenta con mecanismos eficaces para garantizar que los instrumentos de evaluación estén técnicamente elaborados.', 'C'::categoria_pauta, 21),
  ((select id from dimensiones where codigo = 'D3'), '22', 'La carrera desarrolla procesos pertinentes de inducción al estudiantado de nuevo ingreso de acuerdo con los requerimientos de la modalidad en que se imparte (incluye la inducción al uso de plataformas virtuales en caso de ser utilizadas).', 'B'::categoria_pauta, 22),
  ((select id from dimensiones where codigo = 'D3'), '23', 'La universidad o la carrera pone a disposición del estudiantado servicios de apoyo pertinentes para su desarrollo cognitivo, afectivo y social.', 'C'::categoria_pauta, 23),
  ((select id from dimensiones where codigo = 'D3'), '24', 'La carrera proporciona, de manera pública y accesible, información pertinente acerca del perfil académico profesional y plan de estudios vigente, requisitos de ingreso y recursos tecnológicos necesarios para llevar a cabo el proceso de enseñanza-aprendizaje.', 'B'::categoria_pauta, 24),
  ((select id from dimensiones where codigo = 'D3'), '25', 'La carrera sigue el avance del estudiantado mediante estadísticas y procedimientos eficaces y propone acciones para potenciar la progresión oportuna y disminuir la repitencia, el rezago y deserción, incluido un plan de nivelación de quienes procedan de bachilleratos universitarios distintos a la disciplina en la cual se ubica la licenciatura (para carreras que solo ofrecen el tramo de licenciatura y reciben bachilleres de varias carreras afines o no).', 'B'::categoria_pauta, 25),
  ((select id from dimensiones where codigo = 'D3'), '26', 'La carrera cuenta con una normativa institucional y espacios idóneos que garantizan la organización, participación y representación estudiantil en los escenarios correspondientes.', 'D'::categoria_pauta, 26),
  ((select id from dimensiones where codigo = 'D3'), '27', 'La carrera cuenta con un sistema de información que le permite obtener datos relevantes para el seguimiento a las personas graduadas y estos son considerados en la toma de decisiones.', 'C'::categoria_pauta, 27),
  ((select id from dimensiones where codigo = 'D3'), '28', 'La carrera ofrece a sus graduados oportunidades relevantes de educación continua.', 'C'::categoria_pauta, 28),
  ((select id from dimensiones where codigo = 'D4'), '29', 'El personal académico de la carrera es idóneo para atender los requerimientos del plan de estudios vigente (incluyendo las habilidades y las destrezas para la mediación pedagógica) de acuerdo con la modalidad en que se imparte la carrera.', 'A'::categoria_pauta, 29),
  ((select id from dimensiones where codigo = 'D4'), '30', 'El personal académico de la carrera es suficiente para atender la gestión, docencia, trabajos finales de graduación, investigación y extensión.', 'B'::categoria_pauta, 30),
  ((select id from dimensiones where codigo = 'D4'), '31', 'La carrera mantiene relaciones académicas activas pertinentes con centros, grupos, redes o programas dedicados a la investigación científica y educativa, extensión, innovación, diseño y producción artística en su campo disciplinar.', 'B'::categoria_pauta, 31),
  ((select id from dimensiones where codigo = 'D4'), '32', 'La carrera promueve y ejecuta con eficacia la divulgación de la producción académica (resultados de investigación, extensión, innovación, producción artística y trabajos finales de graduación según corresponda) del personal académico y del estudiantado.', 'B'::categoria_pauta, 32),
  ((select id from dimensiones where codigo = 'D4'), '33', 'El personal administrativo, técnico y de apoyo de la carrera es suficiente para atender sus necesidades de gestión.', 'D'::categoria_pauta, 33),
  ((select id from dimensiones where codigo = 'D4'), '34', 'El personal administrativo, técnico y de apoyo de la carrera es idóneo para atender sus necesidades de gestión.', 'D'::categoria_pauta, 34),
  ((select id from dimensiones where codigo = 'D4'), '35', 'La carrera ejecuta con equidad los procesos de selección, contratación, evaluación y promoción del personal académico, administrativo, técnico y de apoyo.', 'C'::categoria_pauta, 35),
  ((select id from dimensiones where codigo = 'D4'), '36', 'La carrera desarrolla procesos pertinentes de inducción para el personal académico, administrativo, técnico y de apoyo de nuevo ingreso de acuerdo con los requerimientos de la modalidad en que se imparte la carrera.', 'B'::categoria_pauta, 36),
  ((select id from dimensiones where codigo = 'D4'), '37', 'El personal académico cuenta con suficiente equipo, accesibilidad y conectividad para llevar a cabo las actividades de aprendizaje, comunicación y atención tutorial y de consultas, de acuerdo con los requerimientos de la modalidad en que se imparte la carrera.', 'B'::categoria_pauta, 37),
  ((select id from dimensiones where codigo = 'D4'), '38', 'La carrera ejecuta acciones eficaces de mejoramiento en los métodos y técnicas de enseñanza y evaluación para los aprendizajes de acuerdo con los requerimientos de la modalidad en que se imparte.', 'B'::categoria_pauta, 38),
  ((select id from dimensiones where codigo = 'D4'), '39', 'La universidad o la carrera realiza o facilita procesos pertinentes de desarrollo profesional y actualización para el personal académico, administrativo, técnico y de apoyo.', 'C'::categoria_pauta, 39),
  ((select id from dimensiones where codigo = 'D4'), '40', 'La carrera cuenta con mecanismos eficaces para la evaluación del desempeño del personal académico, administrativo, técnico y de apoyo y los implementa de manera sistemática para la toma de decisiones.', 'A'::categoria_pauta, 40),
  ((select id from dimensiones where codigo = 'D5'), '41', 'La carrera dispone de la infraestructura física y tecnológica suficiente, según los requerimientos de la modalidad en que se imparte.', 'B'::categoria_pauta, 41),
  ((select id from dimensiones where codigo = 'D5'), '42', 'La universidad o la carrera cuenta con una normativa pertinente referida a higiene, seguridad y salud ocupacional, accesibilidad, prevención de riesgos y atención a desastres naturales.', 'C'::categoria_pauta, 42),
  ((select id from dimensiones where codigo = 'D5'), '43', 'La universidad o la carrera cuenta con políticas pertinentes y realiza acciones para promover la equidad de género.', 'C'::categoria_pauta, 43),
  ((select id from dimensiones where codigo = 'D5'), '44', 'La carrera gestiona eficazmente la demanda de nuevos recursos, el mantenimiento y reemplazo de infraestructura y equipos.', 'D'::categoria_pauta, 44),
  ((select id from dimensiones where codigo = 'D5'), '45', 'La universidad o la carrera cuenta con la normativa eficaz y ejecuta acciones para prevenir y atender el hostigamiento sexual.', 'C'::categoria_pauta, 45),
  ((select id from dimensiones where codigo = 'D6'), '46', 'La persona que dirige la carrera es idónea para el puesto en tanto posee habilidades gerenciales, administrativas, académicas y de liderazgo.', 'C'::categoria_pauta, 46),
  ((select id from dimensiones where codigo = 'D6'), '47', 'Los servicios administrativos y académicos (asincrónicos, sincrónicos y presenciales) que ofrece la carrera atienden de manera eficaz las necesidades del usuario presencial y no presencial.', 'B'::categoria_pauta, 47),
  ((select id from dimensiones where codigo = 'D6'), '48', 'La carrera cuenta con un plan estratégico prospectivo y planes operativos pertinentes para sustentar la ejecución de los procesos educativos y la mejora continua.', 'A'::categoria_pauta, 48),
  ((select id from dimensiones where codigo = 'D6'), '49', 'La carrera y sus actividades no presenciales están respaldadas por una unidad de gestión y soporte informático eficiente que incluya: servicio a personas usuarias, capacidad de almacenamiento, redundancia, encriptación y ciberseguridad, fluidez de la comunicación y adquisición de licencias según sus necesidades, sistema centralizado 24/7.', 'B'::categoria_pauta, 49),
  ((select id from dimensiones where codigo = 'D6'), '50', 'La carrera cuenta con un campus virtual idóneo para albergar las actividades virtuales de la oferta académica: interfaz amigable, responsividad, adaptabilidad, control de acceso, perfiles de usuario, almacenamiento de información de cursos, replicabilidad y accesibilidad.', 'B'::categoria_pauta, 50),
  ((select id from dimensiones where codigo = 'D6'), '51', 'El campus virtual permite una gestión académica idónea de las actividades de aprendizaje no presenciales.', 'B'::categoria_pauta, 51),
  ((select id from dimensiones where codigo = 'D6'), '52', 'La carrera cuenta con sistemas de información eficientes para apoyar el proceso de la gestión y toma de decisiones.', 'C'::categoria_pauta, 52),
  ((select id from dimensiones where codigo = 'D6'), '53', 'La carrera implementa procedimientos eficaces de verificación y resguardo de la información referida a los procesos académicos y a la declaración de cumplimiento de los requisitos de graduación.', 'B'::categoria_pauta, 53),
  ((select id from dimensiones where codigo = 'D6'), '54', 'La carrera implementa mecanismos eficaces para la sostenibilidad de su calidad.', 'B'::categoria_pauta, 54),
  ((select id from dimensiones where codigo = 'D6'), '55', 'La carrera proporciona, de manera transparente, información acerca de:
*Normativa interna
*Trámites académicos y administrativos
*Plan de estudios
*Convenios, incentivos
*Servicios (salud, biblioteca, formación docente y apoyo a personal académico, administrativo, técnico, de apoyo y estudiantes).', 'C'::categoria_pauta, 55),
  ((select id from dimensiones where codigo = 'D6'), '56', 'La universidad o la carrera sigue de manera eficaz los principios de la educación inclusiva y cuenta con los recursos para lograrlo.', 'A'::categoria_pauta, 56),
  ((select id from dimensiones where codigo = 'D6'), '57', 'La carrera pone en práctica mecanismos eficaces de vinculación con el sector social, público y productivos afines a la carrera, así como mecanismos de seguimiento y evaluación de las actividades que emprende con dichos sectores.', 'C'::categoria_pauta, 57),
  ((select id from dimensiones where codigo = 'D6'), '58', 'La universidad o la carrera realiza acciones eficaces para incorporar la dimensión ambiental a su proyecto institucional, educativo y laboral.', 'D'::categoria_pauta, 58),
  ((select id from dimensiones where codigo = 'D6'), '59', 'La carrera gestiona actividades académicas pertinentes en procura de su internacionalización.', 'C'::categoria_pauta, 59)
on conflict (codigo) do update set dimension_id = excluded.dimension_id, nombre = excluded.nombre, categoria = excluded.categoria, orden = excluded.orden;

-- FUENTES (137) — se recarga todo el catálogo
delete from fuentes;
insert into fuentes (pauta_id, tipo, nombre, orden) values
  ((select id from pautas where codigo = '1'), 'I'::tipo_fuente, 'Perfil académico profesional (plan de estudios vigente).', 1),
  ((select id from pautas where codigo = '1'), 'I'::tipo_fuente, 'Malla curricular.', 2),
  ((select id from pautas where codigo = '1'), 'I'::tipo_fuente, 'Programas de cursos (habilidades, destrezas, competencias en relación con el perfil académico profesional).', 3),
  ((select id from pautas where codigo = '2'), 'I'::tipo_fuente, 'Plan de estudios vigente.', 1),
  ((select id from pautas where codigo = '2'), 'I'::tipo_fuente, 'Perfil o requisitos de ingreso.', 2),
  ((select id from pautas where codigo = '3'), 'I'::tipo_fuente, 'Modelo educativo de la universidad.', 1),
  ((select id from pautas where codigo = '3'), 'I'::tipo_fuente, 'Perfil académico profesional (Plan de estudio vigente).', 2),
  ((select id from pautas where codigo = '3'), 'III'::tipo_fuente, 'Tabla con el perfil académico profesional, las estrategias de enseñanza y las estrategias de evaluación.', 3),
  ((select id from pautas where codigo = '3'), 'I'::tipo_fuente, 'Programas de los cursos.', 4),
  ((select id from pautas where codigo = '3'), 'IV'::tipo_fuente, 'Opinión de las personas graduadas de los últimos cuatro años sobre si las capacidades desarrolladas gracias a las estrategias y metodologías de enseñanza y de evaluación fueron pertinentes para alcanzar el perfil académico profesional.', 5),
  ((select id from pautas where codigo = '4'), 'I'::tipo_fuente, 'Malla curricular.', 1),
  ((select id from pautas where codigo = '4'), 'III'::tipo_fuente, 'Cuadro con la indicación de las asignaturas de la carrera y horas dedicadas en cada una de ellas a teoría, prácticas de laboratorio, trabajo independiente, actividades extra clase, entre otros, según corresponda.', 2),
  ((select id from pautas where codigo = '5'), 'I'::tipo_fuente, 'Programa de los cursos.', 1),
  ((select id from pautas where codigo = '5'), 'III'::tipo_fuente, 'Cuadro indicando curso, actividades de aprendizaje, objetivo o resultado del aprendizaje referido en el programa del curso.', 2),
  ((select id from pautas where codigo = '6'), 'I'::tipo_fuente, 'Reglamentos o normativas académicas pertinentes.', 1),
  ((select id from pautas where codigo = '6'), 'III'::tipo_fuente, 'Cuadro comparativo en el que consten los cambios realizados en el plan de estudios en los últimos cuatro años.', 2),
  ((select id from pautas where codigo = '6'), 'III'::tipo_fuente, 'Lista de actividades realizadas y participantes (personal académico, estudiantado, personas graduadas y empleadores) para la revisión y actualización del plan de estudios.', 3),
  ((select id from pautas where codigo = '7'), 'I'::tipo_fuente, 'Plan de estudios de la carrera o documento en el que consten las actividades extracurriculares que desarrolla la carrera.', 1),
  ((select id from pautas where codigo = '8'), 'I'::tipo_fuente, 'Programas de cursos y otras actividades que incorporan recursos didácticos en una segunda lengua.', 1),
  ((select id from pautas where codigo = '8'), 'IV'::tipo_fuente, 'Opinión del estudiantado sobre la idoneidad de los recursos didácticos en una segunda lengua.', 2),
  ((select id from pautas where codigo = '9'), 'III'::tipo_fuente, 'Matriz que asocia la competencia digital, la norma de seguridad y el código de comportamiento que se desarrollan en cada uno de los cursos.', 1),
  ((select id from pautas where codigo = '9'), 'IV'::tipo_fuente, 'Opinión del estudiantado, personas graduadas, empleadores sobre la eficacia de la carrera en el desarrollo de las competencias digitales.', 2),
  ((select id from pautas where codigo = '10'), 'I'::tipo_fuente, 'Plan de estudios (descripción de las asignaturas y su aporte al desarrollo de las competencias de indagación y pensamiento científico).', 1),
  ((select id from pautas where codigo = '11'), 'I'::tipo_fuente, 'Políticas y estrategias establecidas.', 1),
  ((select id from pautas where codigo = '11'), 'III'::tipo_fuente, 'Listas de proyectos, actividades y acciones de investigación, extensión, innovación, diseño y producción artística, según corresponda.  realizadas en los últimos cuatro años y número de participantes.', 2),
  ((select id from pautas where codigo = '11'), 'IV'::tipo_fuente, 'Opinión del personal académico sobre la eficiencia de políticas, recursos y estrategias para promover proyectos, actividades y acciones de investigación, extensión, innovación, diseño y producción artística, según corresponda.', 3),
  ((select id from pautas where codigo = '12'), 'III'::tipo_fuente, 'Lista de proyectos, actividades, programas y acciones de investigación científica y educativa, innovación, diseño, producción artística y extensión, trabajos de graduación y en ejecución o finalizados en los últimos cuatro años.', 1),
  ((select id from pautas where codigo = '13'), 'III'::tipo_fuente, 'Matriz con el eje pedagógico del modelo educativo, la naturaleza de la disciplina y las estrategias de mediación pedagógica que utiliza la carrera.', 1),
  ((select id from pautas where codigo = '14'), 'I'::tipo_fuente, 'Perfil académico profesional.', 1),
  ((select id from pautas where codigo = '14'), 'I'::tipo_fuente, 'Programas de cursos.', 2),
  ((select id from pautas where codigo = '14'), 'III'::tipo_fuente, 'Lista de estrategias de mediación pedagógica.', 3),
  ((select id from pautas where codigo = '15'), 'I'::tipo_fuente, 'Reglamento de Trabajos Finales de Graduación.', 1),
  ((select id from pautas where codigo = '15'), 'IV'::tipo_fuente, 'Opinión de los graduados y egresados de los últimos dos años acerca de la asesoría y supervisión recibida para la elaboración de su trabajo final de graduación y durante su práctica profesional.', 2),
  ((select id from pautas where codigo = '16'), 'II'::tipo_fuente, 'Estrategias de evaluación alternativa que utiliza la carrera.', 1),
  ((select id from pautas where codigo = '16'), 'I'::tipo_fuente, 'Ejemplos de instrumentos para la evaluación de los aprendizajes que utiliza la carrera.', 2),
  ((select id from pautas where codigo = '16'), 'I'::tipo_fuente, 'Reglamentación sobre la evaluación de actividades de aprendizaje.', 3),
  ((select id from pautas where codigo = '16'), 'IV'::tipo_fuente, 'Opinión del estudiantado acerca de la equidad en las actividades de evaluación.', 4),
  ((select id from pautas where codigo = '17'), 'I'::tipo_fuente, 'Normativa de evaluación para los aprendizajes del estudiantado, incluida la práctica profesional.', 1),
  ((select id from pautas where codigo = '17'), 'IV'::tipo_fuente, 'Opinión del estudiantado acerca de si reciben realimentación eficaz en torno a los resultados de las evaluaciones que realizan.', 2),
  ((select id from pautas where codigo = '18'), 'I'::tipo_fuente, 'Lineamiento, mecanismo o instrumento que utiliza la carrera para asegurar el mejoramiento de los procesos pedagógicos, incluida la práctica profesional, según los resultados de las evaluaciones del estudiantado.', 1),
  ((select id from pautas where codigo = '19'), 'II'::tipo_fuente, 'Descripción de cómo se respetan los códigos éticos y legales de uso.', 1),
  ((select id from pautas where codigo = '19'), 'II'::tipo_fuente, 'Descripción de los mecanismos que utiliza la carrera para asegurar la accesibilidad de los materiales y recursos didácticos.', 2),
  ((select id from pautas where codigo = '19'), 'IV'::tipo_fuente, 'Opinión del estudiantado sobre la pertinencia de los materiales y recursos didácticos (físicos y virtuales) utilizados en los cursos de la carrera.', 3),
  ((select id from pautas where codigo = '20'), 'I'::tipo_fuente, 'Programas de los cursos.', 1),
  ((select id from pautas where codigo = '20'), 'IV'::tipo_fuente, 'Opinión del estudiantado sobre la coherencia entre los objetivos de aprendizaje y la mediación pedagógica desarrollada.', 2),
  ((select id from pautas where codigo = '20'), 'IV'::tipo_fuente, 'Opinión del estudiantado sobre la coherencia entre la mediación pedagógica desarrollada y la evaluación para los aprendizajes.', 3),
  ((select id from pautas where codigo = '21'), 'II'::tipo_fuente, 'Descripción de las acciones que realiza la carrera para garantizar que los instrumentos de evaluación estén técnicamente elaborados.', 1),
  ((select id from pautas where codigo = '22'), 'III'::tipo_fuente, 'Listado de acciones de inducción al estudiantado de nuevo ingreso de los últimos dos años, que favorezcan el proceso de transición a la educación universitaria de acuerdo con los requerimientos de la modalidad en que se imparte la carrera.', 1),
  ((select id from pautas where codigo = '22'), 'III'::tipo_fuente, 'Registros de la participación en actividades de inducción: fotografías, videos, listas, memorias gráficas.', 2),
  ((select id from pautas where codigo = '22'), 'II'::tipo_fuente, 'Acciones de acompañamiento experto y técnico a las actividades de inducción para el uso del campus virtual.', 3),
  ((select id from pautas where codigo = '22'), 'IV'::tipo_fuente, 'Opinión del estudiantado de nuevo ingreso sobre la pertinencia de las acciones de inducción de los últimos dos años para favorecer el proceso de transición a la educación universitaria de acuerdo con los requerimientos de la modalidad en que se imparte la carrera.', 4),
  ((select id from pautas where codigo = '23'), 'III'::tipo_fuente, 'Lista de los servicios de apoyo para el desarrollo cognitivo, afectivo y social a los que tiene acceso el estudiantado de la carrera, con indicación del horario y oferta de servicios.', 1),
  ((select id from pautas where codigo = '23'), 'IV'::tipo_fuente, 'Opinión del estudiantado sobre la pertinencia de los servicios de apoyo que recibe para su desarrollo integral (cognitivo, afectivo y social).', 2),
  ((select id from pautas where codigo = '24'), 'III'::tipo_fuente, 'Lista de medios de difusión (físicos o virtuales) utilizados para proporcionar la información acerca del perfil académico profesional y plan de estudios vigente, requisitos, condiciones de ingreso y recursos tecnológicos y de otra naturaleza necesarios para llevar a cabo el proceso de enseñanza-aprendizaje.', 1),
  ((select id from pautas where codigo = '24'), 'IV'::tipo_fuente, 'Opinión del estudiantado acerca de la disponibilidad y pertinencia de la información acerca del perfil académico profesional y plan de estudios vigente.', 2),
  ((select id from pautas where codigo = '24'), 'IV'::tipo_fuente, 'Opinión del estudiantado acerca de la disponibilidad y pertinencia de la información sobre los recursos tecnológicos necesarios para llevar a cabo el proceso de enseñanza-aprendizaje.', 3),
  ((select id from pautas where codigo = '25'), 'III'::tipo_fuente, 'Datos de tasas de aprobación, repitencia, deserción y tiempo promedio de graduación de la última cohorte.', 1),
  ((select id from pautas where codigo = '25'), 'II'::tipo_fuente, 'Descripción de las acciones ejecutadas para evitar la repitencia, el rezago y la deserción estudiantil en la última cohorte, plan de nivelación (atención al estudiantado, flexibilidad curricular, cursos electivos, diversificación de modalidades de trabajos finales de graduación, oferta oportuna de cursos, orientación vocacional, becas, centros de estudio, entre otras acciones).', 2),
  ((select id from pautas where codigo = '26'), 'I'::tipo_fuente, 'Normativa institucional que faculta la organización estudiantil.', 1),
  ((select id from pautas where codigo = '26'), 'IV'::tipo_fuente, 'Opinión del estudiantado sobre la idoneidad de la normativa institucional y de los espacios para su organización, participación y representación en los escenarios correspondientes.', 2),
  ((select id from pautas where codigo = '27'), 'II'::tipo_fuente, 'Instrumento de seguimiento a graduados.', 1),
  ((select id from pautas where codigo = '27'), 'II'::tipo_fuente, 'Descripción de las acciones que incorporan la información aportada por las personas graduadas.', 2),
  ((select id from pautas where codigo = '28'), 'III'::tipo_fuente, 'Listado de las actividades de educación continua, realizadas por la carrera en los últimos dos años, indicando temáticas abordadas y cantidad de participantes.', 1),
  ((select id from pautas where codigo = '28'), 'IV'::tipo_fuente, 'Opinión de las personas graduadas en los últimos dos años sobre la relevancia de la educación continua de la carrera para el ejercicio y actualización profesional.', 2),
  ((select id from pautas where codigo = '29'), 'I'::tipo_fuente, 'Currículo vitae del personal académico.', 1),
  ((select id from pautas where codigo = '29'), 'III'::tipo_fuente, 'Cuadro con datos del personal académico indicando grados académicos y experiencia profesional y académica (en docencia, extensión e investigación), producción académica, administración académica y otros atestados relevantes de acuerdo con la modalidad en que se imparte la carrera, de los últimos cuatro años.', 2),
  ((select id from pautas where codigo = '29'), 'I'::tipo_fuente, 'Instrumento de evaluación del desempeño aplicado al personal académico.', 3),
  ((select id from pautas where codigo = '29'), 'III'::tipo_fuente, 'Resultados de la evaluación del desempeño más reciente aplicada al personal académico de la carrera (no es necesario indicar los nombres).', 4),
  ((select id from pautas where codigo = '29'), 'IV'::tipo_fuente, 'Opinión del estudiantado acerca de la idoneidad de las habilidades, destrezas y la experiencia del personal académico para la mediación pedagógica en la modalidad en la que se imparte la carrera.', 5),
  ((select id from pautas where codigo = '30'), 'II'::tipo_fuente, 'Jornada de contratación de la persona que ocupa la dirección de la carrera.', 1),
  ((select id from pautas where codigo = '30'), 'III'::tipo_fuente, 'Listado de todo el personal académico con su jornada de contratación, indicando tiempo dedicado a docencia, investigación, extensión y administración académica.', 2),
  ((select id from pautas where codigo = '30'), 'III'::tipo_fuente, 'Lista de acciones de docencia, investigación, acción social y gestión que realizan las personas docentes.', 3),
  ((select id from pautas where codigo = '30'), 'IV'::tipo_fuente, 'Opinión del personal académico sobre la suficiencia de las horas asignadas a docencia, investigación, extensión y administración académica para cumplir con las tareas asociadas a dicha labor.', 4),
  ((select id from pautas where codigo = '31'), 'III'::tipo_fuente, 'Cuadro en el cual se indican los centros, grupos, redes o programas dedicados a la investigación científica y educativa, extensión, innovación, diseño y producción artística y los productos obtenidos y acciones ejecutadas en cada caso en los últimos cuatro años.', 1),
  ((select id from pautas where codigo = '32'), 'III'::tipo_fuente, 'Cuadro con los resultados de la producción académica, personas autoras/participantes y medio de divulgación utilizado en los últimos cuatro años.', 1),
  ((select id from pautas where codigo = '32'), 'IV'::tipo_fuente, 'Opinión del personal académico y del estudiantado sobre la eficacia de la carrera para divulgar la producción académica relacionada con la disciplina.', 2),
  ((select id from pautas where codigo = '33'), 'III'::tipo_fuente, 'Lista del personal administrativo, técnico y de apoyo de la carrera con indicación general de su función y tiempo asignado.', 1),
  ((select id from pautas where codigo = '33'), 'IV'::tipo_fuente, 'Opinión del personal académico y del estudiantado de la carrera sobre la suficiencia del personal administrativo para desarrollar sus funciones.', 2),
  ((select id from pautas where codigo = '34'), 'I'::tipo_fuente, 'El perfil del puesto y los atestados del personal administrativo, técnico y de apoyo que atiende la carrera.', 1),
  ((select id from pautas where codigo = '35'), 'I'::tipo_fuente, 'Políticas de gestión de recursos humanos y/o políticas de equidad.', 1),
  ((select id from pautas where codigo = '35'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo sobre si los procesos de promoción, selección, contratación y evaluación se realizan con equidad.', 2),
  ((select id from pautas where codigo = '36'), 'III'::tipo_fuente, 'Listado de acciones de inducción en las que ha participado el personal académico, administrativo, técnico y de apoyo de nuevo ingreso en los últimos dos años de acuerdo con los requerimientos de la modalidad en que se imparte la carrera.', 1),
  ((select id from pautas where codigo = '36'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo que ha ingresado a la carrera en los últimos dos años sobre la existencia, pertinencia y calidad del proceso de inducción.', 2),
  ((select id from pautas where codigo = '37'), 'III'::tipo_fuente, 'Lista de equipo disponible para que el personal académico pueda llevar a cabo las actividades de aprendizaje, comunicación y atención tutorial y de consultas, de acuerdo con los requerimientos de la modalidad en que se imparte la carrera.', 1),
  ((select id from pautas where codigo = '37'), 'IV'::tipo_fuente, 'Opinión del personal académico acerca de la suficiencia del equipo disponible, la accesibilidad y conectividad para llevar a cabo las actividades de aprendizaje, comunicación y atención tutorial y consultas, de acuerdo con los requerimientos de la modalidad en que se imparte la carrera.', 2),
  ((select id from pautas where codigo = '38'), 'III'::tipo_fuente, 'Lista de acciones de capacitación en métodos y técnicas de enseñanza y evaluación, de acuerdo con la modalidad en que se imparte, en las que ha participado el personal académico en los últimos dos años.', 1),
  ((select id from pautas where codigo = '38'), 'IV'::tipo_fuente, 'Opinión del personal académico sobre la eficacia de las acciones de mejoramiento en métodos y técnicas de enseñanza y evaluación, de acuerdo con la modalidad en que se imparte, realizadas en los últimos dos años.', 2),
  ((select id from pautas where codigo = '39'), 'II'::tipo_fuente, 'Diagnóstico de necesidades de actualización y desarrollo profesional del personal académico, administrativo, técnico y de apoyo.', 1),
  ((select id from pautas where codigo = '39'), 'III'::tipo_fuente, 'Listado de las acciones de actualización impartidas al personal académico, administrativo, técnico y de apoyo en los últimos dos años.', 2),
  ((select id from pautas where codigo = '39'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo sobre la calidad y pertinencia de las actividades de actualización facilitadas por la universidad o la carrera en las que ha participado en los últimos dos años.', 3),
  ((select id from pautas where codigo = '40'), 'I'::tipo_fuente, 'Reglamento o normativa institucional para la evaluación del desempeño del personal académico y del personal administrativo, técnico y de apoyo.', 1),
  ((select id from pautas where codigo = '40'), 'I'::tipo_fuente, 'Instrumentos para evaluar el desempeño del personal académico y del personal administrativo, técnico y de apoyo.', 2),
  ((select id from pautas where codigo = '40'), 'II'::tipo_fuente, 'Descripción sobre el uso de los resultados de la evaluación del desempeño del personal académico y del personal administrativo, técnico y de apoyo.', 3),
  ((select id from pautas where codigo = '40'), 'IV'::tipo_fuente, 'Opinión de estudiantado en torno a la atención de sus valoraciones sobre el desempeño del personal académico.', 4),
  ((select id from pautas where codigo = '40'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo sobre la eficacia del proceso de evaluación del desempeño y la realimentación recibida.', 5),
  ((select id from pautas where codigo = '41'), 'III'::tipo_fuente, 'Lista de la infraestructura física y tecnológica disponible para el desarrollo de la carrera, de acuerdo con los requerimientos de la modalidad en que se imparte.', 1),
  ((select id from pautas where codigo = '41'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo y estudiantado sobre la suficiencia de la infraestructura física y tecnológica para el quehacer académico de la carrera, de acuerdo con los requerimientos de la modalidad en que se imparte.', 2),
  ((select id from pautas where codigo = '42'), 'I'::tipo_fuente, 'Normativa referida a higiene, seguridad y salud ocupacional, accesibilidad, prevención de riesgos y atención a desastres naturales.', 1),
  ((select id from pautas where codigo = '42'), 'I'::tipo_fuente, 'Plan de atención a emergencias y desastres naturales.', 2),
  ((select id from pautas where codigo = '42'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo, y estudiantado sobre la pertinencia de la normativa referida a higiene, seguridad, accesibilidad, salud ocupacional, prevención de riesgos y atención a los desastres naturales en la carrera.', 3),
  ((select id from pautas where codigo = '43'), 'I'::tipo_fuente, 'Políticas sobre equidad de género.', 1),
  ((select id from pautas where codigo = '43'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo, y estudiantado acerca de la pertinencia de las políticas y las acciones que realiza la carrera para asegurar la equidad de género.', 2),
  ((select id from pautas where codigo = '44'), 'I'::tipo_fuente, 'Plan de mantenimiento y reemplazo de infraestructura y equipos.', 1),
  ((select id from pautas where codigo = '44'), 'II'::tipo_fuente, 'Evidencia de las gestiones que ha realizado la carrera y sus resultados para el mantenimiento y reemplazo de infraestructura y equipos, así como la adquisición de nuevos recursos (en caso de requerirse).', 2),
  ((select id from pautas where codigo = '45'), 'I'::tipo_fuente, 'Normativa para la prevención y atención del hostigamiento sexual.', 1),
  ((select id from pautas where codigo = '45'), 'II'::tipo_fuente, 'Descripción de las funciones asignadas a las instancias encargadas de la protección y derechos ante situaciones de hostigamiento sexual.', 2),
  ((select id from pautas where codigo = '45'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo, y estudiantado sobre la pertinencia y cumplimiento de la normativa de prevención y atención del hostigamiento sexual, así como sobre la acción de las instancias de protección.', 3),
  ((select id from pautas where codigo = '46'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo acerca de la idoneidad de la persona que dirige la carrera.', 1),
  ((select id from pautas where codigo = '47'), 'I'::tipo_fuente, 'Normativa relativa a la disponibilidad horaria y velocidad de respuesta de los servicios académicos y dependencias administrativas.', 1),
  ((select id from pautas where codigo = '47'), 'IV'::tipo_fuente, 'Opinión del estudiantado con respecto a la eficacia de los servicios administrativos y académicos para solventar sus necesidades.', 2),
  ((select id from pautas where codigo = '48'), 'I'::tipo_fuente, 'Plan estratégico de la carrera.', 1),
  ((select id from pautas where codigo = '48'), 'I'::tipo_fuente, 'Plan operativo anual vigente.', 2),
  ((select id from pautas where codigo = '49'), 'I'::tipo_fuente, 'Protocolos atinentes a la gestión y soporte informático.', 1),
  ((select id from pautas where codigo = '49'), 'I'::tipo_fuente, 'Organigrama institucional en el que conste la unidad de gestión y el soporte informático.', 2),
  ((select id from pautas where codigo = '49'), 'II'::tipo_fuente, 'Certificación de la unidad de gestión y soporte informático por parte de la autoridad universitaria competente.', 3),
  ((select id from pautas where codigo = '49'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo, y estudiantado en torno a la eficiencia del soporte informático que brinda la carrera.', 4),
  ((select id from pautas where codigo = '50'), 'I'::tipo_fuente, 'Lineamientos y procedimientos (protocolos) para la sostenibilidad y operación de la integralidad de la infraestructura tecnológica, así como su mantenimiento y actualización.', 1),
  ((select id from pautas where codigo = '50'), 'II'::tipo_fuente, 'Descripción de anchos de banda en torno a su capacidad para ofrecer conexión óptima en alta recurrencia y tráfico de información.', 2),
  ((select id from pautas where codigo = '50'), 'II'::tipo_fuente, 'Descripción del software disponible en torno a su capacidad para proteger la intromisión de terceros.', 3),
  ((select id from pautas where codigo = '50'), 'II'::tipo_fuente, 'Descripción de las características de los servidores y los procedimientos (protocolos) en torno a su capacidad para asegurar su redundancia y respaldo permanente y en casos de emergencia.', 4),
  ((select id from pautas where codigo = '50'), 'IV'::tipo_fuente, 'Opinión del personal académico y del estudiantado sobre la idoneidad del campus virtual para la implementación de la carrera.', 5),
  ((select id from pautas where codigo = '51'), 'IV'::tipo_fuente, 'Opinión del personal académico y del estudiantado acerca de la idoneidad del campus virtual para gestionar las actividades de aprendizaje no presenciales.', 1),
  ((select id from pautas where codigo = '52'), 'III'::tipo_fuente, 'Tabla con indicación de cada sistema de información y su función.', 1),
  ((select id from pautas where codigo = '53'), 'II'::tipo_fuente, 'Descripción del procedimiento de verificación y resguardo de la información.', 1),
  ((select id from pautas where codigo = '53'), 'III'::tipo_fuente, 'Lista de medidas de seguridad en los títulos y certificaciones.', 2),
  ((select id from pautas where codigo = '54'), 'II'::tipo_fuente, 'Descripción de los mecanismos que utiliza la carrera para la sostenibilidad de su calidad.', 1),
  ((select id from pautas where codigo = '55'), 'III'::tipo_fuente, 'Lista de medios de comunicación mediante los cuales la carrera proporciona información relevante sobre su quehacer.', 1),
  ((select id from pautas where codigo = '55'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo, y estudiantado acerca de la transparencia de la información proporcionada por la carrera.', 2),
  ((select id from pautas where codigo = '56'), 'II'::tipo_fuente, 'Políticas de educación inclusiva.', 1),
  ((select id from pautas where codigo = '56'), 'III'::tipo_fuente, 'Listado de recursos de apoyo educativo para atender a la diversidad del estudiantado.', 2),
  ((select id from pautas where codigo = '56'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo, y estudiantado acerca de si la carrera sigue de forma eficaz los principios de inclusión.', 3),
  ((select id from pautas where codigo = '57'), 'III'::tipo_fuente, 'Listado de acciones de vinculación con el sector social, público y productivo de los últimos dos años, con indicación del sector (gremio, empresa, grupo organizado, institución pública, etc.) y de los resultados obtenidos.', 1),
  ((select id from pautas where codigo = '58'), 'III'::tipo_fuente, 'Listado de acciones relativas al logro de una gestión ambiental sostenible y sus resultados en los últimos dos años.', 1),
  ((select id from pautas where codigo = '58'), 'IV'::tipo_fuente, 'Opinión del personal académico, administrativo, técnico y de apoyo, y estudiantado sobre la eficacia de los esfuerzos de la carrera para incorporar la dimensión ambiental a su proyecto institucional, educativo y laboral.', 2),
  ((select id from pautas where codigo = '59'), 'I'::tipo_fuente, 'Normativa aplicable a la carrera que le brinda posibilidades para realizar actividades de internacionalización.', 1),
  ((select id from pautas where codigo = '59'), 'I'::tipo_fuente, 'Listado de actividades de internacionalización de los últimos dos años, tales como movilidad e intercambios académicos de personal académico y estudiantado, relaciones académicas de cooperación e intercambio internacional entre otras acciones realizadas en forma virtual y presencial.', 2),
  ((select id from pautas where codigo = '59'), 'II'::tipo_fuente, 'Elementos del plan de estudios que evidencian una propuesta curricular hacia la formación para una ciudadanía global.', 3);
