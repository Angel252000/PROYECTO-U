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
