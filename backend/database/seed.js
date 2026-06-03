const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'sinaes.db');
const db = new sqlite3.Database(dbPath);

const dimensiones = [
    { nombre: 'Relación con el contexto', descripcion: 'Dimensión 1 del SINAES' },
    { nombre: 'Recursos humanos', descripcion: 'Dimensión 2 del SINAES' },
    { nombre: 'Currículo', descripcion: 'Dimensión 3 del SINAES' },
    { nombre: 'Estudiantes', descripcion: 'Dimensión 4 del SINAES' },
    { nombre: 'Administración', descripcion: 'Dimensión 5 del SINAES' },
    { nombre: 'Infraestructura', descripcion: 'Dimensión 6 del SINAES' }
];

db.serialize(() => {
    // Insertar Dimensiones
    const stmtDim = db.prepare("INSERT INTO dimensiones (nombre, descripcion) VALUES (?, ?)");
    dimensiones.forEach(dim => {
        stmtDim.run(dim.nombre, dim.descripcion);
    });
    stmtDim.finalize();

    // Insertar Pautas de ejemplo (59 pautas)
    const categorias = ['A', 'B', 'C', 'D'];
    const pautasCount = 59;
    const stmtPauta = db.prepare("INSERT INTO pautas (dimension_id, codigo, nombre, descripcion, categoria) VALUES (?, ?, ?, ?, ?)");

    for (let i = 1; i <= pautasCount; i++) {
        const dimId = Math.floor((i - 1) / 10) + 1; // Distribuir pautas entre dimensiones
        const codigo = `P${i}`;
        const nombre = `Pauta ${i}`;
        const descripcion = `Descripción detallada de la pauta ${i} del modelo SINAES.`;
        const categoria = categorias[Math.floor(Math.random() * categorias.length)];
        stmtPauta.run(dimId > 6 ? 6 : dimId, codigo, nombre, descripcion, categoria);
    }
    stmtPauta.finalize();

    // Insertar Fuentes de ejemplo
    const tiposFuente = ['I', 'II', 'III', 'IV'];
    const stmtFuente = db.prepare("INSERT INTO fuentes (pauta_id, tipo, nombre) VALUES (?, ?, ?)");
    for (let i = 1; i <= 59; i++) {
        const numFuentes = Math.floor(Math.random() * 3) + 1;
        for (let j = 1; j <= numFuentes; j++) {
            const tipo = tiposFuente[Math.floor(Math.random() * tiposFuente.length)];
            stmtFuente.run(i, tipo, `Fuente ${j} para Pauta ${i}`);
        }
    }
    stmtFuente.finalize();

    console.log("Seeding completado con éxito.");
});

db.close();
