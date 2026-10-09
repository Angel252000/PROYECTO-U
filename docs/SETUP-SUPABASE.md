# 🚀 Guía: crear Supabase y conectar la app SINAES

Sigue estos pasos en orden. Es gratis y toma ~10 minutos.

## 1) Crear el proyecto en Supabase
1. Entra a <https://supabase.com> e inicia sesión (puedes usar GitHub).
2. Clic en **New project**.
3. Completa:
   - **Name:** `sinaes`
   - **Database Password:** crea una y **guárdala** (la necesitarás).
   - **Region:** elige la más cercana (ej. *East US (North Virginia)*).
4. Clic en **Create new project** y espera ~2 minutos a que se aprovisione.

## 2) Cargar el esquema y los datos (la forma fácil: un solo archivo)
En el menú izquierdo: **SQL Editor** → **New query**.
Abre el archivo **`supabase/INSTALAR_TODO.sql`**, selecciona todo (Cmd+A),
cópialo, pégalo en el editor y pulsa **Run**.

Ese único archivo crea TODO de una vez: las tablas, la seguridad y los datos
reales (6 dimensiones, 59 pautas, 137 fuentes).

> Verifica: en una query nueva corre `select count(*) from pautas;` → debe dar **59**.

<details><summary>Alternativa: cargar archivo por archivo</summary>

Si prefieres, ejecuta en orden cada archivo de `supabase/migrations/`
(`0001` → `0008`) y al final `supabase/seed.sql`.
</details>

## 3) Permitir el registro rápido (para probar)
**Authentication → Providers → Email** → desactiva temporalmente
**"Confirm email"** y guarda. Así puedes crear tu usuario y entrar al instante
(luego se reactiva para producción).

## 4) Copiar las llaves de tu proyecto
**Project Settings → API** y copia:
- **Project URL**
- **anon public** key

## 5) Conectar la app
En tu computadora, dentro de la carpeta del proyecto:
```bash
cd webapp
cp .env.local.example .env.local
```
Abre `webapp/.env.local` y pega tus valores:
```
NEXT_PUBLIC_SUPABASE_URL=https://TU-PROYECTO.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu-anon-key
```

## 6) Levantar la app
```bash
cd webapp
npm run dev
```
Abre <http://localhost:3000>:
1. **Crea tu cuenta** (botón "Crear una").
2. **Crea tu proceso** (institución, carrera, año).
3. Ve a **Pautas** → verás las **59 pautas reales** y podrás evaluarlas.
4. El **Dashboard** mostrará el progreso calculándose solo.

---

## (Opcional, para más adelante)
- **Storage de evidencias:** Storage → New bucket → nombre `evidencias`.
- **Roles por proceso:** se gestionan en la tabla `miembros_proceso`.
