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
