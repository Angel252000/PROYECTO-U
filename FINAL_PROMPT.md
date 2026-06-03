# 🧠 FINAL PROMPT - SINAES Self-Evaluation Platform

## Goal
Desarrollar una plataforma web completa para la gestión de autoevaluación y auditoría académica conforme al Modelo de Acreditación de Grado del SINAES (59 pautas, 6 dimensiones), incluyendo backend, frontend, base de datos, lógica de evaluación y automatización.

## Technical Architecture
- **Backend:** Node.js + Express (API REST)
- **Database:** SQLite (Relational schema)
- **Frontend:** Single Page Application (Tailwind CSS + Chart.js)
- **Deployment:** Compatible with local servers or institution hosting.

## Features Implemented
### 1. Database Schema
Optimized SQLite schema with tables for:
- `dimensiones`, `pautas`, `fuentes`, `evaluaciones`, `evidencias`, `auditorias`, `subprocesos`, `plan_mejora`.

### 2. Analytical Dashboard
- Real-time KPIs (Progress %, Evaluated guidelines, Total Score).
- Radar Chart for dimension-based conformity.
- Progress bars for historical and current trends.

### 3. Guidelines & Evaluation
- Table with traffic light status (Red/Yellow/Green).
- Evaluation modal with:
    - Conformity selection (100%, 50%, 0%).
    - Argumentation text area.
    - Evidence file upload.
    - **Intelligent Guide:** Step-by-step subprocesses per guideline.

### 4. Engines
- **Gap Analysis:** Identifies and prioritizes guidelines by category weight (A > B > C > D) and compliance gap.
- **Audit Bot:** Automated report flagging missing evidence or weak arguments.
- **Improvement Plan:** Module to manage activities, responsibilities, and deadlines.

### 5. Export
- SINAES-compatible CSV export for Excel integration.

---

## Source Code logic
### Scoring Formula
`Total Score = sum(CategoryWeight * (Conformity / 100))`
- Category A: 2.5 | B: 2 | C: 1.5 | D: 1

### Audit Status
- **Green:** Compliant + Evidence + Argument.
- **Yellow:** Compliant but weak argument.
- **Red:** Missing evidence or non-compliant.

---

## How to Run
1. Navigate to `backend/` and run `npm install`.
2. Run `node database/seed.js` to initialize data.
3. Start server with `node index.js`.
4. Open `frontend/index.html` in your browser.
