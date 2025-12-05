#!/bin/bash
# ====================================================
# SETUP SCRIPT - SISTEMA HONEYPOT AUTH
# ESCOM - Equipo Decepticons
# ====================================================

set -e  # Detener en errores

echo ""
echo ""
echo "=========================================="
echo "   CONFIGURACION INICIAL DEL PROYECTO"
echo "=========================================="
echo ""

# Colores y formato para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# FUNCIÓN: Mostrar encabezado
header() {
    echo ""
    echo "=========================================="
    echo "   $1"
    echo "=========================================="
    echo ""
}

# FUNCIÓN: Mostrar mensaje importante
important_msg() {
    echo ""
    echo -e "${BOLD}${BLUE}>>> $1${NC}"
    echo ""
}

# FUNCIÓN: Mostrar mensaje de éxito
success_msg() {
    echo -e "${GREEN}[OK] $1${NC}"
}

# FUNCIÓN: Mostrar advertencia
warning_msg() {
    echo -e "${YELLOW}[ATENCION] $1${NC}"
}

# FUNCIÓN: Mostrar error
error_msg() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# FUNCIÓN: Mostrar mensaje crítico
critical_msg() {
    echo ""
    echo -e "${BOLD}${RED}=========================================="
    echo "   $1"
    echo "==========================================${NC}"
    echo ""
}

# FUNCIÓN: Verificar seguridad de Git
check_git_safety() {
    header "VERIFICANDO SEGURIDAD GIT"
    
    # Verificar si .env está en staging
    if git status --porcelain | grep -q "^A.*\.env$" || git status --porcelain | grep -q "^M.*\.env$"; then
        critical_msg "PELIGRO DE SEGURIDAD"
        echo "El archivo .env está en staging de Git"
        echo "Esto expondría tus credenciales si haces commit!"
        echo ""
        important_msg "SOLUCION REQUERIDA"
        echo "Ejecuta: git reset .env"
        echo "Luego verifica con: git status"
        return 1
    fi
    
    # Verificar si .env está siendo rastreado
    if git ls-files | grep -q "^\.env$"; then
        critical_msg "PELIGRO CRITICO DETECTADO"
        echo "El archivo .env está siendo rastreado por Git"
        echo "¡Tus credenciales podrían estar comprometidas!"
        echo ""
        important_msg "ACCION INMEDIATA REQUERIDA"
        echo "1. Ejecuta: git rm --cached .env"
        echo "2. Verifica que '.env' esté en .gitignore"
        echo "3. Cambia TODAS tus contraseñas expuestas inmediatamente"
        return 2
    fi
    
    success_msg "Git está en estado seguro"
    return 0
}

# FUNCIÓN: Limpiar archivos de entorno previos
cleanup_env_files() {
    header "LIMPIANDO ARCHIVOS PREVIOS"
    
    # Hacer backup si existe .env antiguo
    if [ -f ".env" ]; then
        BACKUP_NAME=".env.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Creando backup: $BACKUP_NAME"
        cp .env "$BACKUP_NAME"
        success_msg "Backup creado correctamente"
    fi
    
    # Eliminar .env si es solo ejemplo
    if [ -f ".env" ] && grep -q "usuario_ejemplo\|password123\|admin@example.com" .env 2>/dev/null; then
        warning_msg "Eliminando .env con credenciales de ejemplo..."
        rm .env
    fi
}

# FUNCIÓN: Crear archivo .env seguro
create_env_file() {
    header "CREANDO ARCHIVO DE CONFIGURACION"
    
    if [ ! -f ".env.example" ]; then
        error_msg "Archivo .env.example no encontrado"
        echo "Asegurate de clonar el repositorio completo primero"
        exit 1
    fi
    
    if [ ! -f ".env" ]; then
        echo "Copiando configuración desde .env.example..."
        cp .env.example .env
        success_msg "Archivo .env creado correctamente"
    else
        warning_msg "El archivo .env ya existe"
    fi
    
    # Verificar credenciales de ejemplo
    important_msg "VERIFICANDO CREDENCIALES"
    if grep -q "usuario:contraseña\|password123\|admin@example.com" .env; then
        critical_msg "CREDENCIALES DE EJEMPLO DETECTADAS"
        echo ""
        echo "DEBES EDITAR EL ARCHIVO .env Y CAMBIAR:"
        echo ""
        echo "1. DATABASE_URL: Tu conexión real a PostgreSQL"
        echo "   Formato: postgresql://usuario:contraseña@localhost:5432/honeypot_db"
        echo ""
        echo "2. SESSION_SECRET: Genera uno nuevo con el comando:"
        echo "   openssl rand -hex 32"
        echo ""
        important_msg "INSTRUCCIONES"
        echo "Comando para editar: nano .env"
        echo "(o usa tu editor de texto favorito)"
        echo ""
        critical_msg "ADVERTENCIA FINAL"
        echo "NO HAGAS COMMIT SIN CAMBIAR ESTAS CREDENCIALES"
        echo "EXPORIAS INFORMACION SENSIBLE"
    else
        success_msg "Las credenciales parecen estar personalizadas"
    fi
}

# FUNCIÓN: Verificar PostgreSQL
check_postgresql() {
    header "VERIFICANDO POSTGRESQL"
    
    if command -v pg_isready >/dev/null 2>&1; then
        if pg_isready -q; then
            success_msg "PostgreSQL está corriendo correctamente"
        else
            warning_msg "PostgreSQL instalado pero no está corriendo"
            echo ""
            echo "Para iniciar PostgreSQL:"
            echo "   brew services start postgresql@16"
            echo ""
            echo "O si no usas Homebrew:"
            echo "   pg_ctl -D /usr/local/var/postgres start"
        fi
    else
        warning_msg "PostgreSQL no está detectado en el sistema"
        echo ""
        echo "Para instalar PostgreSQL en macOS:"
        echo "   brew install postgresql"
        echo ""
        echo "Para otros sistemas, consulta la documentación oficial"
    fi
}

# FUNCIÓN: Mostrar instrucciones finales
show_final_instructions() {
    header "CONFIGURACION COMPLETADA"
    
    important_msg "PRÓXIMOS PASOS"
    echo ""
    echo "1. EDITAR CONFIGURACION"
    echo "   Comando: nano .env"
    echo "   Cambia las credenciales por tus valores reales"
    echo ""
    echo "2. CONFIGURAR BASE DE DATOS"
    echo "   Ejecuta estos comandos:"
    echo "   createdb honeypot_db"
    echo '   psql -c "CREATE USER tu_usuario WITH PASSWORD '\''tu_contraseña'\'';"'
    echo ""
    echo "3. INICIAR LA APLICACION"
    echo "   npm run dev"
    echo ""
    echo "4. ACCEDER A LA APLICACION"
    echo "   Abre tu navegador en: http://localhost:3000"
    echo ""
    
    important_msg "VERIFICACION DE SEGURIDAD FINAL"
    echo "Antes de cualquier commit, verifica con:"
    echo "   git status"
    echo ""
    echo "El archivo .env NO debe aparecer en la lista"
    echo "Si aparece, ejecuta: git reset .env"
    
    echo ""
    echo "=========================================="
    echo "   Soporte: Contacta al equipo Decepticons"
    echo "=========================================="
    echo ""
}

# ===== EJECUCIÓN PRINCIPAL =====

# 1. Limpieza inicial
cleanup_env_files

# 2. Crear archivo .env
create_env_file

# 3. Verificar PostgreSQL
check_postgresql

# 4. Instalar dependencias (si existe package.json)
if [ -f "package.json" ]; then
    header "INSTALANDO DEPENDENCIAS"
    echo "Instalando paquetes de Node.js..."
    npm install
    success_msg "Dependencias instaladas correctamente"
fi

# 5. Verificar seguridad Git (al final)
check_git_safety

# 6. Mostrar instrucciones finales
show_final_instructions

# 7. Recordatorio final de seguridad
critical_msg "RECORDATORIO CRITICO DE SEGURIDAD"
echo "NUNCA hagas commit del archivo .env al repositorio"
echo ""
echo "Verifica siempre antes de commit:"
echo "   git status"
echo ""
echo "Si .env aparece en los cambios, ejecuta:"
echo "   git reset .env"
echo ""
echo "Mantén tus credenciales siempre en secreto"
echo "=========================================="
