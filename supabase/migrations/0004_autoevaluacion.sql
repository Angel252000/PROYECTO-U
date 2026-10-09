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
