import express from "express";
import session from "express-session";
import helmet from "helmet";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

// Configurar __dirname para ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Cargar variables de entorno
dotenv.config();

const app = express();

// Seguridad básica con helmet
app.use(helmet());

// Procesar datos de formularios
app.use(express.urlencoded({ extended: true }));

// Configurar sesiones de usuario
app.use(session({
  secret: process.env.SESSION_SECRET,  // Clave desde .env
  resave: false,                       // No guardar sesión si no cambia
  saveUninitialized: false,            // No crear sesiones vacías
  cookie: { 
    httpOnly: true,                    // Cookie no accesible desde JS
    sameSite: "strict",                // Protección CSRF
    secure: false                      // true solo con HTTPS
  }
}));

// Middleware para mensajes temporales (flash)
app.use((req, res, next) => {
  // Pasar mensajes a vistas
  res.locals.success = req.session.success;
  res.locals.error = req.session.error;
  
  // Limpiar mensajes después de usarlos
  delete req.session.success;
  delete req.session.error;
  
  next();
});

// Configurar motor de plantillas EJS
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

// Importar y usar rutas
import authRoutes from "./routes/authRoutes.js";    // Rutas de autenticación
import adminRoutes from "./routes/adminRoutes.js";  // Rutas de administración

app.use("/", authRoutes);      // Rutas principales
app.use("/admin", adminRoutes); // Rutas con prefijo /admin

// Redirigir raíz a login
app.get("/", (req, res) => {
  res.redirect("/login");
});

// Iniciar servidor
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Servidor ejecutándose en http://localhost:${PORT}`);
});