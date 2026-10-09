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
