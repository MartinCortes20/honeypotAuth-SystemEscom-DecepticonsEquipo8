// Importar Express para crear rutas
import express from "express";

// Importar controlador de administración
import { adminPage } from "../controllers/adminController.js";

// Crear enrutador para rutas /admin
const router = express.Router();

// Ruta GET /admin/ → Muestra panel de administración
router.get("/", adminPage);

// Exportar enrutador para usar en app principal
export default router;