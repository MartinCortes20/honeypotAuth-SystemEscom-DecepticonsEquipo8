// Importar Express para crear rutas
import express from "express";

// Importar funciones del controlador de autenticación
import { 
  showLogin,      // Muestra formulario login
  showRegister,   // Muestra formulario registro
  registerUser,   // Procesa registro nuevo usuario
  loginUser,      // Procesa inicio de sesión
  logoutUser,     // Cierra sesión usuario
  userPage,        // Muestra página usuario autenticado
  showProfile  // Agrega esta importación

} from "../controllers/authController.js";

// Importar middleware de protección honeypot
import { honeypotProtection } from "../middleware/honeypotProtection.js";

// Crear enrutador para rutas principales
const router = express.Router();

// RUTAS GET (mostrar páginas)
router.get("/login", showLogin);          // GET /login → Formulario login
router.get("/register", showRegister);    // GET /register → Formulario registro
router.get("/user", userPage);            // GET /user → Página usuario (protegida)
router.get("/logout", logoutUser);        // GET /logout → Cerrar sesión
router.get("/profile", showProfile);  // Agrega esta nueva ruta


// RUTAS POST (procesar datos)
router.post("/login", honeypotProtection, loginUser);     // POST /login → Verifica credenciales
router.post("/register", honeypotProtection, registerUser); // POST /register → Crea usuario

// Exportar enrutador para usar en app principal
export default router;
