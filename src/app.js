import express from "express";
import session from "express-session";
import helmet from "helmet";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

// Fix para __dirname en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

const app = express();

// Middleware de seguridad
app.use(helmet());

// Parsear formularios
app.use(express.urlencoded({ extended: true }));

// Configurar sesiones
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: { 
    httpOnly: true, 
    sameSite: "strict",
    secure: false // Cambiar a true en producción con HTTPS
  }
}));

//  MIDDLEWARE NUEVO: Mensajes flash para UX
app.use((req, res, next) => {
  // Pasar mensajes de éxito/error a todas las vistas
  res.locals.success = req.session.success;
  res.locals.error = req.session.error;
  
  // Limpiar después de usarlos
  delete req.session.success;
  delete req.session.error;
  
  next();
});

// Configurar EJS
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

// Rutas
import authRoutes from "./routes/authRoutes.js";
import adminRoutes from "./routes/adminRoutes.js";

app.use("/", authRoutes);
app.use("/admin", adminRoutes);

// Ruta principal
app.get("/", (req, res) => {
  res.redirect("/login");
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Servidor Decepticon ejecutándose en http://localhost:${PORT}`);
});