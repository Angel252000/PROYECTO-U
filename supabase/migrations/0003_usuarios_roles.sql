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
