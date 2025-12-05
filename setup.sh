#!/bin/bash
# ====================================================
# SETUP COMPLETO - SISTEMA HONEYPOT AUTH
# ESCOM - Equipo Decepticons
# ====================================================

set -e  # Detener en errores

echo ""
echo "=========================================="
echo "   CONFIGURACION AUTOMATICA DEL PROYECTO"
echo "=========================================="
echo ""

# Colores y formato
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Funciones de mensajes
success() { echo -e "${GREEN}[✓] $1${NC}"; }
warning() { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[✗] $1${NC}"; }
info() { echo -e "${BLUE}[i] $1${NC}"; }
header() { echo -e "\n${BOLD}=== $1 ===${NC}"; }

# ============================================
# FUNCIONES PRINCIPALES
# ============================================

configurar_entorno() {
    header "CONFIGURANDO VARIABLES DE ENTORNO"
    
    # Crear .env desde ejemplo
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            success "Archivo .env creado desde plantilla"
        else
            error "No se encontró .env.example"
            exit 1
        fi
    fi
    
    # Generar SESSION_SECRET automáticamente
    if grep -q "SESSION_SECRET=\"genera_con:" .env; then
        NEW_SECRET=$(openssl rand -hex 32)
        sed -i '' "s/SESSION_SECRET=\".*\"/SESSION_SECRET=\"$NEW_SECRET\"/" .env
        success "SESSION_SECRET generado automáticamente"
    fi
    
    # Pedir credenciales de PostgreSQL si son de ejemplo
    if grep -q "usuario:contraseña" .env; then
        warning "Credenciales de PostgreSQL son de ejemplo"
        echo ""
        read -p "¿Tu usuario de PostgreSQL? (default: $USER): " PG_USER
        PG_USER=${PG_USER:-$USER}
        
        read -sp "¿Contraseña para $PG_USER? (no se mostrará): " PG_PASS
        echo ""
        
        # Actualizar .env
        sed -i '' "s|postgresql://usuario:contraseña|postgresql://$PG_USER:$PG_PASS|" .env
        success "Credenciales de PostgreSQL actualizadas"
    fi
}

instalar_dependencias() {
    header "INSTALANDO DEPENDENCIAS"
    
    if [ -f "package.json" ]; then
        npm install
        success "Dependencias de Node.js instaladas"
    else
        warning "No se encontró package.json"
    fi
}

verificar_postgresql() {
    header "VERIFICANDO POSTGRESQL"
    
    # Verificar si PostgreSQL está instalado
    if ! command -v psql &> /dev/null; then
        warning "PostgreSQL no está instalado"
        echo "Para instalar en macOS: brew install postgresql"
        echo "En Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
        return 1
    fi
    
    # Verificar si el servicio está corriendo
    if ! pg_isready -q; then
        warning "PostgreSQL no está corriendo"
        
        # Intentar iniciar
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew services start postgresql 2>/dev/null || brew services start postgresql@16 2>/dev/null
            sleep 3
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo service postgresql start 2>/dev/null || sudo systemctl start postgresql 2>/dev/null
            sleep 3
        fi
        
        if pg_isready -q; then
            success "PostgreSQL iniciado correctamente"
        else
            error "No se pudo iniciar PostgreSQL. Inicia manualmente:"
            echo "  macOS: brew services start postgresql"
            echo "  Linux: sudo service postgresql start"
            return 1
        fi
    else
        success "PostgreSQL está corriendo"
    fi
    return 0
}

configurar_base_datos() {
    header "CONFIGURANDO BASE DE DATOS"
    
    # Extraer credenciales del .env
    DB_URL=$(grep DATABASE_URL .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    DB_USER=$(echo $DB_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    DB_PASS=$(echo $DB_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_NAME=$(echo $DB_URL | sed -n 's/.*@[^/]*\/\([^?]*\).*/\1/p')
    
    echo "Usuario: $DB_USER"
    echo "Base de datos: $DB_NAME"
    
    # Crear usuario si no existe
    if ! psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
        info "Creando usuario PostgreSQL: $DB_USER"
        psql -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || \
        warning "No se pudo crear el usuario (puede que ya exista)"
    else
        success "Usuario $DB_USER ya existe"
    fi
    
    # Crear base de datos si no existe
    if ! psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
        info "Creando base de datos: $DB_NAME"
        createdb $DB_NAME 2>/dev/null || \
        psql -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || \
        warning "No se pudo crear la base de datos"
    else
        success "Base de datos $DB_NAME ya existe"
    fi
    
    # Otorgar permisos
    info "Otorgando permisos..."
    psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || true
    psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;" 2>/dev/null || true
    
    success "Base de datos configurada"
}

configurar_prisma() {
    header "CONFIGURANDO PRISMA"
    
    if [ -f "prisma/schema.prisma" ]; then
        info "Generando cliente Prisma..."
        npx prisma generate
        
        info "Ejecutando migraciones..."
        npx prisma migrate dev --name init 2>/dev/null || \
        npx prisma db push 2>/dev/null || \
        warning "No se pudieron ejecutar migraciones automáticamente"
        
        success "Prisma configurado"
    else
        warning "No se encontró schema.prisma"
    fi
}

verificar_seguridad_git() {
    header "VERIFICANDO SEGURIDAD GIT"
    
    # Verificar que .env no esté en staging
    if git status --porcelain | grep -q "^[AM].*\.env$"; then
        error "PELIGRO: .env está en staging de Git"
        echo "Ejecuta: git reset .env"
        echo "Para removerlo del área de staging"
    else
        success ".env no está en staging"
    fi
    
    # Verificar que .env esté en .gitignore
    if grep -q "^\.env$" .gitignore; then
        success ".env está en .gitignore"
    else
        warning ".env no está en .gitignore"
        echo ".env" >> .gitignore
        success ".env agregado a .gitignore"
    fi
}

# ============================================
# EJECUCIÓN PRINCIPAL
# ============================================

main() {
    echo ""
    info "Iniciando configuración automática..."
    echo ""
    
    # 1. Configurar entorno
    configurar_entorno
    
    # 2. Instalar dependencias
    instalar_dependencias
    
    # 3. Verificar PostgreSQL
    if verificar_postgresql; then
        # 4. Configurar base de datos
        configurar_base_datos
        
        # 5. Configurar Prisma
        configurar_prisma
    else
        warning "Saltando configuración de base de datos (PostgreSQL no disponible)"
    fi
    
    # 6. Verificar seguridad Git
    verificar_seguridad_git
    
    # 7. Resultado final
    header "CONFIGURACION COMPLETADA"
    
    echo ""
    success "¡Proyecto configurado exitosamente!"
    echo ""
    echo "Para iniciar la aplicación:"
    echo "  ${BOLD}npm run dev${NC}"
    echo ""
    echo "La aplicación estará disponible en:"
    echo "  ${BOLD}http://localhost:3000${NC}"
    echo ""
    echo "Credenciales generadas:"
    echo "  - PostgreSQL: En el archivo .env"
    echo "  - Session Secret: Generado automáticamente"
    echo ""
    echo "Si hay problemas:"
    echo "  1. Revisa que PostgreSQL esté corriendo"
    echo "  2. Verifica las credenciales en .env"
    echo "  3. Ejecuta: npx prisma migrate dev"
    echo ""
    echo "=========================================="
    echo ""
}

# Ejecutar función principal
main