# 🎓 Plataforma SINAES — Autoevaluación y Acreditación

Plataforma web para gestionar el proceso de **autoevaluación y acreditación**
conforme al **Modelo de Grado 2025 del SINAES** (dimensiones, 59 pautas,
fuentes I–IV, encuestas, evidencias, evaluación externa y plan de mejora).

> **Estado:** migrando de un prototipo (Node + SQLite) a una plataforma real
> sobre **Supabase (PostgreSQL)**. Esta es la **Fase 0: base sólida** — el
> esquema completo de la base de datos ya está listo.

---

## 🧱 Arquitectura

| Capa | Tecnología | Rol |
|---|---|---|
| **Base de datos** | Supabase · PostgreSQL | Datos, roles, seguridad por fila, tiempo real |
| **Autenticación** | Supabase Auth | Login por roles (estudiante, docente, coordinador, par evaluador…) |
| **Archivos** | Supabase Storage | Evidencias Tipo I–IV |
| **Lógica** | Vistas + funciones SQL · Edge Functions | Scoring, gap analysis, bot auditor, informes IA |
| **Frontend** | Next.js + TypeScript + Tailwind + Recharts (`webapp/`) | Dashboard, pautas, encuestas, evidencias |

### Mapa de módulos (la visión completa)
```
1. Datos institucionales ─┐
2. Encuestas (Tipo IV) ────┤
3. Evidencias (I–IV) ──────┼──► 4. Evaluación de pautas ──► 5. Informe (IA)
                           │                                      │
9. Dashboard ◄── 8. Plan de mejora ◄── 7. Evaluación externa ◄────┘
```

---

## 🗂️ Estructura del repositorio
```
PROYECTO-U/
├── supabase/
│   ├── migrations/        ← esquema PostgreSQL (8 migraciones ordenadas)
│   ├── seed.sql           ← datos reales (6 dim · 59 pautas · 137 fuentes)
│   ├── INSTALAR_TODO.sql  ← instalador en un solo archivo (todo lo anterior)
│   └── import/            ← scripts que extraen el modelo desde el Excel oficial
├── webapp/                ← app web (Next.js + TypeScript + Supabase)
│   └── .env.local         ← ÚNICO archivo de variables (URL + anon key)
├── docs/
│   ├── SETUP-SUPABASE.md  ← guía para crear y conectar Supabase
│   └── fuentes-oficiales/ ← AQUÍ van los Excel oficiales del SINAES
└── README.md
```

### Qué hace cada migración
| Archivo | Contenido |
|---|---|
| `0001_extensiones_y_tipos.sql` | Tipos (ENUM) y funciones base (pesos, mapeos) |
| `0002_modelo_catalogo.sql` | Instituciones, carreras, procesos, dimensiones, **pautas**, fuentes, subprocesos |
| `0003_usuarios_roles.sql` | Perfiles + roles por proceso + helpers de permisos |
| `0004_autoevaluacion.sql` | Evaluaciones, evidencias, auditorías, plan de mejora |
| `0005_encuestas.sql` | Cuestionarios, preguntas, opciones, invitaciones, respuestas |
| `0006_evaluacion_externa.sql` | Informes de pares + valoraciones |
| `0007_funciones_vistas.sql` | **Dashboard, scoring, gap analysis, bot auditor** (en SQL) |
| `0008_rls.sql` | Seguridad por fila (quién ve y edita qué) |

---

## 🚀 Puesta en marcha (sin instalar nada)

### 1) Crear el proyecto en Supabase
1. Entra a <https://supabase.com> → **New project**.
2. Anota la contraseña de la base de datos.
3. En **Project Settings → API** copia `URL` y `anon key` (luego al `.env`).

### 2) Cargar el esquema (vía editor SQL del navegador)
En el panel de Supabase → **SQL Editor** → **New query**, y ejecuta en orden
el contenido de cada archivo de `supabase/migrations/`, del `0001` al `0008`.
Luego ejecuta `supabase/seed.sql`.

> Cada migración es independiente y se puede volver a correr sin romper nada
> (usa `if not exists` / `on conflict`).

### 3) (Opcional) Vía Supabase CLI
```bash
npm install -g supabase           # instalar CLI
supabase login
supabase link --project-ref TU-REF
supabase db push                  # aplica las migraciones
```

### 4) Variables de entorno (un solo archivo)
La app lee **`webapp/.env.local`**. Debe tener exactamente:
```
NEXT_PUBLIC_SUPABASE_URL=https://TU-PROYECTO.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...    # la "anon public" key (token largo)
```
Tras editarlo, **reinicia** `npm run dev` (Next.js solo lo lee al arrancar).
Guía detallada en `docs/SETUP-SUPABASE.md`.

---

## ✅ Cómo verificar que quedó bien
En el **SQL Editor** de Supabase:
```sql
-- Deben aparecer las 6 dimensiones y 2 pautas de ejemplo
select * from dimensiones order by orden;
select codigo, nombre, categoria from pautas;

-- El dashboard responde aunque aún no haya proceso con datos
select * from vw_dashboard;
```

---

## 🛣️ Próximos pasos (roadmap)
- [x] **Fase 0** — Base sólida: esquema PostgreSQL completo
- [x] **Fase 1** — Datos reales cargados: **6 dimensiones, 59 pautas, 137 fuentes** desde el Formato 1 oficial
- [~] **Fase 2** — App web en `webapp/` (Next.js + Supabase): login, dashboard y módulo de pautas ← *en marcha; falta conectar Supabase*
- [ ] **Fase 3** — Módulo de encuestas dinámicas (Tipo IV)
- [ ] **Fase 4** — Módulo de evidencias + dashboard en tiempo real
- [ ] **Fase 5** — Generador de informe con IA (Claude)
- [ ] **Fase 6** — Evaluación externa + plan de mejora + seguimiento

## 🔁 Importación de datos del modelo
Los datos oficiales se extraen del Excel **Formato 1** con scripts reproducibles:
```
supabase/import/
├── extraer_modelo.py        # lee el Formato 1.xlsx → modelo_grado_2025.json
├── generar_seed.py          # JSON → supabase/seed.sql (datos reales)
└── modelo_grado_2025.json   # datos extraídos (6 dim · 59 pautas · 137 fuentes)
```
Para regenerar si cambia el modelo:
```bash
python3 -m venv .venv-import && ./.venv-import/bin/pip install openpyxl
./.venv-import/bin/python supabase/import/extraer_modelo.py "ruta/al/Formato 1.xlsx"
./.venv-import/bin/python supabase/import/generar_seed.py
```
