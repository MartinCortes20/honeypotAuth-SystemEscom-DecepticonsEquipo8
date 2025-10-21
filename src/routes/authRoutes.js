import express from "express";
import { 
  showLogin, 
  showRegister, 
  registerUser, 
  loginUser, 
  logoutUser, 
  userPage 
} from "../controllers/authController.js";
import { honeypotProtection } from "../middleware/honeypotProtection.js";

const router = express.Router();

router.get("/login", showLogin);
router.post("/login", honeypotProtection, loginUser);
router.get("/register", showRegister);
router.post("/register", honeypotProtection, registerUser);
router.get("/user", userPage);
router.get("/logout", logoutUser);

export default router;