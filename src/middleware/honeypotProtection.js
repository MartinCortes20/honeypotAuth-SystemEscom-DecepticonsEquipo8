export function honeypotProtection(req, res, next) {
  if (req.body.hiddenField && req.body.hiddenField.trim() !== "") {
    console.log("🤖 Bot detectado - campo honeypot lleno:", req.body.hiddenField);
    return res.status(403).send("Acceso bloqueado por actividad sospechosa.");
  }
  next();
}