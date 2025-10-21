import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export async function adminPage(req, res) {
  try {
    if (!req.session.userId || req.session.userRole !== "admin") {
      return res.status(403).send("Acceso denegado");
    }

    const users = await prisma.user.findMany({
      select: {
        id: true,
        email: true,
        role: true,
        createdAt: true
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    res.render("admin", { users });
  } catch (error) {
    console.error("Error en panel admin:", error);
    res.status(500).send("Error interno del servidor");
  }
}