import express from "express";
import { adminPage } from "../controllers/adminController.js";

const router = express.Router();

router.get("/", adminPage);

export default router;