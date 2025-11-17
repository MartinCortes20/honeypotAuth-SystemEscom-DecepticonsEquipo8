import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";

const prisma = new PrismaClient();

// FUNCIONES QUE FALTAN - AGREGA ESTAS
export function showLogin(req, res) {
  res.render("login", { error: null, success: null });
}

export function showRegister(req, res) {
  res.render("register", { error: null, success: null });
}

export function userPage(req, res) {
  if (!req.session.userId) {
    return res.redirect("/login");
  }
  res.render("user", { 
    user: { email: req.session.userEmail },
    success: null 
  });
}

// TUS FUNCIONES EXISTENTES
export async function registerUser(req, res) {
  try {
    const { email, password } = req.body;
    
    // Verificar si el usuario ya existe
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      return res.render("register", { error: "El usuario ya existe" });
    }

    // Hash de la contraseña
    const hashedPassword = await bcrypt.hash(password, 10);

    // Crear usuario (el primer usuario será admin)
    const userCount = await prisma.user.count();
    const role = userCount === 0 ? "admin" : "user";

    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        role
      }
    });

    req.session.userId = user.id;
    req.session.userRole = user.role;
    req.session.userEmail = user.email;

    //  MENSAJE DE ÉXITO
    req.session.success = role === 'admin' 
      ? '¡Registro exitoso! Eres el primer usuario (Administrador).' 
      : '¡Registro exitoso! Bienvenido al sistema.';

    if (user.role === "admin") {
      res.redirect("/admin");
    } else {
      res.redirect("/user");
    }
  } catch (error) {
    console.error("Error en registro:", error);
    res.render("register", { error: "Error en el registro" });
  }
}

export async function loginUser(req, res) {
  try {
    const { email, password } = req.body;

    // Buscar usuario
    const user = await prisma.user.findUnique({
      where: { email }
    });

    if (!user) {
      return res.render("login", { error: "Credenciales inválidas" });
    }

    // Verificar contraseña
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.render("login", { error: "Credenciales inválidas" });
    }

    // Crear sesión
    req.session.userId = user.id;
    req.session.userRole = user.role;
    req.session.userEmail = user.email;

    // MENSAJE DE ÉXITO EN LOGIN
    req.session.success = `¡Bienvenido de nuevo, ${user.email}!`;

    if (user.role === "admin") {
      res.redirect("/admin");
    } else {
      res.redirect("/user");
    }
  } catch (error) {
    console.error("Error en login:", error);
    res.render("login", { error: "Error en el login" });
  }
}

export function logoutUser(req, res) {
  //  MENSAJE DE ÉXITO EN LOGOUT
  req.session.success = "Sesión cerrada correctamente";
  
  req.session.destroy((err) => {
    if (err) {
      console.error("Error al cerrar sesión:", err);
    }
    res.redirect("/login");
  });
}