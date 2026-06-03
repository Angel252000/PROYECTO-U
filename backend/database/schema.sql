-- Dimensiones del Modelo SINAES
CREATE TABLE IF NOT EXISTS dimensiones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    descripcion TEXT
);

-- Pautas de acreditación (59 pautas)
CREATE TABLE IF NOT EXISTS pautas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dimension_id INTEGER,
    codigo TEXT NOT NULL,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    categoria TEXT CHECK(categoria IN ('A', 'B', 'C', 'D')),
    FOREIGN KEY (dimension_id) REFERENCES dimensiones(id)
);

-- Fuentes de información (137 fuentes)
CREATE TABLE IF NOT EXISTS fuentes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pauta_id INTEGER,
    tipo TEXT CHECK(tipo IN ('I', 'II', 'III', 'IV')),
    nombre TEXT NOT NULL,
    FOREIGN KEY (pauta_id) REFERENCES pautas(id)
);

-- Evaluaciones
CREATE TABLE IF NOT EXISTS evaluaciones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pauta_id INTEGER UNIQUE,
    conformidad INTEGER CHECK(conformidad IN (0, 50, 100)),
    argumentacion TEXT,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pauta_id) REFERENCES pautas(id)
);

-- Evidencias cargadas
CREATE TABLE IF NOT EXISTS evidencias (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pauta_id INTEGER,
    nombre_archivo TEXT NOT NULL,
    ruta_archivo TEXT NOT NULL,
    fecha_carga DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pauta_id) REFERENCES pautas(id)
);

-- Subprocesos por pauta (Guía Inteligente)
CREATE TABLE IF NOT EXISTS subprocesos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pauta_id INTEGER,
    descripcion TEXT NOT NULL,
    orden INTEGER,
    FOREIGN KEY (pauta_id) REFERENCES pautas(id)
);

-- Auditorías internas
CREATE TABLE IF NOT EXISTS auditorias (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pauta_id INTEGER,
    estado TEXT CHECK(estado IN ('verde', 'amarillo', 'rojo')),
    hallazgos TEXT,
    acciones_correctivas TEXT,
    fecha_auditoria DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pauta_id) REFERENCES pautas(id)
);

-- Plan de Mejora
CREATE TABLE IF NOT EXISTS plan_mejora (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pauta_id INTEGER,
    actividad TEXT NOT NULL,
    responsable TEXT,
    plazo DATE,
    recursos TEXT,
    prioridad TEXT CHECK(prioridad IN ('Alta', 'Media', 'Baja')),
    FOREIGN KEY (pauta_id) REFERENCES pautas(id)
);
