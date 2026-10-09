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
