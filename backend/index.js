const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const path = require('path');
const multer = require('multer');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Database connection
const fs = require('fs');

// Asegurar directorios
const uploadsDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);

const dbPath = path.resolve(__dirname, 'database/sinaes.db');
const db = new sqlite3.Database(dbPath);

// Inicializar base de datos si no existe
const schemaPath = path.resolve(__dirname, 'database/schema.sql');
const schema = fs.readFileSync(schemaPath, 'utf8');
db.exec(schema, (err) => {
    if (err) console.error("Error al inicializar esquema:", err);
    else console.log("Esquema verificado/inicializado.");
});

// Configuración de Multer para evidencias
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, path.join(__dirname, '../uploads'));
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + '-' + file.originalname);
    }
});
const upload = multer({ storage });

// Helper for DB queries
const query = (sql, params = []) => {
    return new Promise((resolve, reject) => {
        db.all(sql, params, (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
        });
    });
};

// Endpoints
app.get('/api/dimensiones', async (req, res) => {
    try {
        const rows = await query("SELECT * FROM dimensiones");
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/pautas', async (req, res) => {
    try {
        const sql = `
            SELECT p.*, e.conformidad, e.argumentacion
            FROM pautas p
            LEFT JOIN evaluaciones e ON p.id = e.pauta_id
        `;
        const rows = await query(sql);
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/pautas/:id', async (req, res) => {
    try {
        const pauta = await query("SELECT * FROM pautas WHERE id = ?", [req.params.id]);
        if (pauta.length === 0) return res.status(404).json({ error: "Pauta no encontrada" });

        const fuentes = await query("SELECT * FROM fuentes WHERE pauta_id = ?", [req.params.id]);
        const evidencias = await query("SELECT * FROM evidencias WHERE pauta_id = ?", [req.params.id]);
        const evaluacion = await query("SELECT * FROM evaluaciones WHERE pauta_id = ?", [req.params.id]);
        const subprocesos = await query("SELECT * FROM subprocesos WHERE pauta_id = ? ORDER BY orden", [req.params.id]);

        res.json({
            ...pauta[0],
            fuentes,
            evidencias,
            evaluacion: evaluacion[0] || null,
            subprocesos
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST para guardar evaluación
app.post('/api/evaluaciones', async (req, res) => {
    const { pauta_id, conformidad, argumentacion } = req.body;
    try {
        await new Promise((resolve, reject) => {
            db.run(
                `INSERT INTO evaluaciones (pauta_id, conformidad, argumentacion, fecha_actualizacion)
                 VALUES (?, ?, ?, CURRENT_TIMESTAMP)
                 ON CONFLICT(pauta_id) DO UPDATE SET
                    conformidad = excluded.conformidad,
                    argumentacion = excluded.argumentacion,
                    fecha_actualizacion = CURRENT_TIMESTAMP`,
                [pauta_id, conformidad, argumentacion],
                (err) => {
                    if (err) reject(err);
                    else resolve();
                }
            );
        });
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST para subir evidencias
app.post('/api/evidencias', upload.single('archivo'), async (req, res) => {
    const { pauta_id } = req.body;
    const { filename, path: filePath } = req.file;
    try {
        await new Promise((resolve, reject) => {
            db.run(
                "INSERT INTO evidencias (pauta_id, nombre_archivo, ruta_archivo) VALUES (?, ?, ?)",
                [pauta_id, filename, filePath],
                (err) => {
                    if (err) reject(err);
                    else resolve();
                }
            );
        });
        res.json({ success: true, filename });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Bot Auditor Engine
app.get('/api/audit', async (req, res) => {
    try {
        const pautas = await query(`
            SELECT p.id, p.codigo, p.nombre, e.conformidad, e.argumentacion,
                   (SELECT COUNT(*) FROM evidencias WHERE pauta_id = p.id) as num_evidencias
            FROM pautas p
            LEFT JOIN evaluaciones e ON p.id = e.pauta_id
            WHERE e.conformidad IS NOT NULL
        `);

        const report = pautas.map(p => {
            let status = 'verde';
            const missing = [];

            if (!p.argumentacion || p.argumentacion.length < 10) {
                status = 'amarillo';
                missing.push('Argumentación insuficiente');
            }
            if (p.num_evidencias === 0) {
                status = 'rojo';
                missing.push('Falta evidencia documental');
            }

            return { ...p, status, missing };
        });

        res.json(report);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Exportar a CSV (compatible con Excel SINAES)
app.get('/api/export', async (req, res) => {
    try {
        const rows = await query(`
            SELECT p.codigo, p.nombre, p.categoria, e.conformidad, e.argumentacion
            FROM pautas p
            LEFT JOIN evaluaciones e ON p.id = e.pauta_id
        `);

        let csv = "Codigo,Pauta,Categoria,Conformidad,Argumentacion\n";
        rows.forEach(r => {
            csv += `"${r.codigo}","${r.nombre}","${r.categoria}","${r.conformidad || 0}%","${(r.argumentacion || '').replace(/"/g, '""')}"\n`;
        });

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', 'attachment; filename=sinaes_export.csv');
        res.send(csv);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Gap Analysis Engine
app.get('/api/gap-analysis', async (req, res) => {
    try {
        const pautas = await query(`
            SELECT p.*, e.conformidad
            FROM pautas p
            LEFT JOIN evaluaciones e ON p.id = e.pauta_id
            WHERE e.conformidad IS NULL OR e.conformidad < 100
        `);

        const catWeight = { 'A': 4, 'B': 3, 'C': 2, 'D': 1 };

        // Priorizar por impacto (Categoría) y nivel de brecha
        const analysis = pautas.map(p => {
            const gap = 100 - (p.conformidad || 0);
            const priorityScore = gap * catWeight[p.categoria];
            return { ...p, gap, priorityScore };
        }).sort((a, b) => b.priorityScore - a.priorityScore);

        res.json(analysis);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Endpoint de Dashboard con cálculo de puntajes
app.get('/api/dashboard', async (req, res) => {
    try {
        const pautas = await query(`
            SELECT p.id, p.dimension_id, p.categoria, e.conformidad
            FROM pautas p
            LEFT JOIN evaluaciones e ON p.id = e.pauta_id
        `);

        const catScores = { 'A': 2.5, 'B': 2, 'C': 1.5, 'D': 1 };

        let totalMaxScore = 0;
        let totalObtainedScore = 0;
        let pautasEvaluadas = 0;

        const dimStats = {};

        pautas.forEach(p => {
            const maxScore = catScores[p.categoria] || 0;
            const conformity = p.conformidad !== null ? p.conformidad / 100 : 0;
            const obtainedScore = maxScore * conformity;

            totalMaxScore += maxScore;
            totalObtainedScore += obtainedScore;
            if (p.conformidad !== null) pautasEvaluadas++;

            if (!dimStats[p.dimension_id]) {
                dimStats[p.dimension_id] = { max: 0, obtained: 0, count: 0 };
            }
            dimStats[p.dimension_id].max += maxScore;
            dimStats[p.dimension_id].obtained += obtainedScore;
            dimStats[p.dimension_id].count++;
        });

        const overallProgress = (totalObtainedScore / totalMaxScore) * 100 || 0;

        res.json({
            overallProgress,
            totalObtainedScore,
            totalMaxScore,
            pautasEvaluadas,
            totalPautas: pautas.length,
            dimStats
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`Servidor corriendo en http://localhost:${PORT}`);
});
