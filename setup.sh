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

# Detectar sistema operativo
detectar_so() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# ============================================
# FUNCIONES PRINCIPALES
# ============================================

instalar_postgresql() {
    local SO=$(detectar_so)
    
    header "INSTALACION DE POSTGRESQL REQUERIDA"
    
    case $SO in
        "macos")
            echo "Para instalar PostgreSQL en macOS:"
            echo ""
            echo "1. Si tienes Homebrew (recomendado):"
            echo "   brew install postgresql"
            echo "   brew services start postgresql"
            echo ""
            echo "2. Descargar instalador oficial:"
            echo "   https://www.postgresql.org/download/macosx/"
            echo ""
            echo "3. Usar Postgres.app (más fácil):"
            echo "   https://postgresapp.com/"
            ;;
        "linux")
            echo "Para instalar PostgreSQL en Linux:"
            echo ""
            echo "Ubuntu/Debian:"
            echo "   sudo apt update"
            echo "   sudo apt install postgresql postgresql-contrib"
            echo "   sudo systemctl start postgresql"
            echo "   sudo systemctl enable postgresql"
            echo ""
            echo "Fedora/RHEL/CentOS:"
            echo "   sudo dnf install postgresql-server"
            echo "   sudo postgresql-setup --initdb"
            echo "   sudo systemctl start postgresql"
            ;;
        "windows")
            echo "Para instalar PostgreSQL en Windows:"
            echo ""
            echo "1. Descargar instalador:"
            echo "   https://www.postgresql.org/download/windows/"
            echo ""
            echo "2. Usar WSL2 (recomendado para desarrollo):"
            echo "   wsl --install"
            echo "   Luego seguir instrucciones para Linux"
            echo ""
            echo "3. Usar Docker:"
            echo "   docker run --name postgres -e POSTGRES_PASSWORD=password -d -p 5432:5432 postgres"
            ;;
        *)
            echo "Visita: https://www.postgresql.org/download/"
            ;;
    esac
    
    echo ""
    echo "Después de instalar PostgreSQL, ejecuta este script nuevamente."
    echo ""
    read -p "¿Quieres intentar instalar automáticamente? (s/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        case $SO in
            "macos")
                if command -v brew &> /dev/null; then
                    info "Instalando PostgreSQL via Homebrew..."
                    brew install postgresql
                    brew services start postgresql
                    sleep 5
                else
                    error "Homebrew no está instalado"
                    echo "Instala Homebrew primero: https://brew.sh/"
                fi
                ;;
            "linux")
                info "Intentando instalar PostgreSQL..."
                # Intentar detectar distribución
                if command -v apt &> /dev/null; then
                    sudo apt update && sudo apt install -y postgresql postgresql-contrib
                    sudo systemctl start postgresql
                elif command -v yum &> /dev/null; then
                    sudo yum install -y postgresql-server
                    sudo postgresql-setup --initdb
                    sudo systemctl start postgresql
                elif command -v dnf &> /dev/null; then
                    sudo dnf install -y postgresql-server
                    sudo postgresql-setup --initdb
                    sudo systemctl start postgresql
                fi
                ;;
        esac
    fi
    
    exit 1
}

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
    if grep -q "SESSION_SECRET=\"genera_con:" .env || grep -q "SESSION_SECRET=\"\"" .env; then
        NEW_SECRET=$(openssl rand -hex 32)
        sed -i '' "s/SESSION_SECRET=\".*\"/SESSION_SECRET=\"$NEW_SECRET\"/" .env 2>/dev/null || \
        sed -i "s/SESSION_SECRET=\".*\"/SESSION_SECRET=\"$NEW_SECRET\"/" .env
        success "SESSION_SECRET generado automáticamente: $NEW_SECRET"
    fi
    
    # Pedir credenciales de PostgreSQL si son de ejemplo
    if grep -q "usuario:contraseña" .env; then
        warning "Credenciales de PostgreSQL son de ejemplo"
        echo ""
        
        # Sugerir nombre de usuario del sistema
        SUGERIDO=$(whoami)
        read -p "¿Tu usuario de PostgreSQL? [$SUGERIDO]: " PG_USER
        PG_USER=${PG_USER:-$SUGERIDO}
        
        read -sp "¿Contraseña para $PG_USER? (no se mostrará): " PG_PASS
        echo ""
        
        if [ -z "$PG_PASS" ]; then
            PG_PASS="password123"  # Contraseña simple por defecto
            warning "Usando contraseña por defecto: $PG_PASS"
            warning "¡Cambia esta contraseña en producción!"
        fi
        
        # Actualizar .env
        sed -i '' "s|postgresql://usuario:contraseña|postgresql://$PG_USER:$PG_PASS|" .env 2>/dev/null || \
        sed -i "s|postgresql://usuario:contraseña|postgresql://$PG_USER:$PG_PASS|" .env
        success "Credenciales de PostgreSQL actualizadas"
        
        # Guardar credenciales para uso posterior
        export DB_USER="$PG_USER"
        export DB_PASS="$PG_PASS"
    else
        # Extraer credenciales existentes
        DB_URL=$(grep DATABASE_URL .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
        export DB_USER=$(echo $DB_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
        export DB_PASS=$(echo $DB_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    fi
}

verificar_postgresql() {
    header "VERIFICANDO POSTGRESQL"
    
    # Verificar si PostgreSQL está instalado
    if ! command -v psql &> /dev/null; then
        warning "PostgreSQL no está instalado"
        instalar_postgresql
        return 1
    fi
    
    # Verificar si el servicio está corriendo
    if ! pg_isready -q 2>/dev/null; then
        warning "PostgreSQL no está corriendo"
        
        # Intentar iniciar basado en SO
        local SO=$(detectar_so)
        
        case $SO in
            "macos")
                info "Intentando iniciar PostgreSQL en macOS..."
                brew services start postgresql 2>/dev/null || \
                brew services start postgresql@14 2>/dev/null || \
                brew services start postgresql@15 2>/dev/null || \
                brew services start postgresql@16 2>/dev/null || {
                    error "No se pudo iniciar PostgreSQL"
                    echo "Inicia manualmente: brew services start postgresql"
                    return 1
                }
                ;;
            "linux")
                info "Intentando iniciar PostgreSQL en Linux..."
                sudo service postgresql start 2>/dev/null || \
                sudo systemctl start postgresql 2>/dev/null || {
                    error "No se pudo iniciar PostgreSQL"
                    echo "Inicia manualmente: sudo service postgresql start"
                    return 1
                }
                ;;
            *)
                error "Inicia PostgreSQL manualmente"
                return 1
                ;;
        esac
        
        # Esperar a que inicie
        info "Esperando que PostgreSQL inicie..."
        for i in {1..10}; do
            if pg_isready -q 2>/dev/null; then
                success "PostgreSQL iniciado correctamente"
                sleep 2
                return 0
            fi
            echo -n "."
            sleep 1
        done
        
        error "PostgreSQL no respondió a tiempo"
        return 1
    else
        success "PostgreSQL está corriendo"
        return 0
    fi
}

configurar_base_datos() {
    header "CONFIGURANDO BASE DE DATOS"
    
    # Extraer nombre de base de datos
    DB_URL=$(grep DATABASE_URL .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    DB_NAME=$(echo $DB_URL | sed -n 's/.*@[^/]*\/\([^?]*\).*/\1/p')
    
    echo "Usuario: $DB_USER"
    echo "Base de datos: $DB_NAME"
    
    # Crear usuario si no existe
    info "Verificando usuario PostgreSQL..."
    if ! psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" 2>/dev/null | grep -q 1; then
        info "Creando usuario: $DB_USER"
        psql -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null && \
        success "Usuario creado" || \
        warning "No se pudo crear el usuario (puede que ya exista o haya error de permisos)"
    else
        success "Usuario ya existe"
    fi
    
    # Crear base de datos si no existe
    info "Verificando base de datos..."
    if ! psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null | grep -q 1; then
        info "Creando base de datos: $DB_NAME"
        createdb $DB_NAME 2>/dev/null || \
        psql -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null && \
        success "Base de datos creada" || \
        warning "No se pudo crear la base de datos"
    else
        success "Base de datos ya existe"
    fi
    
    # Otorgar permisos
    info "Configurando permisos..."
    psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || true
    psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;" 2>/dev/null || true
    psql -d $DB_NAME -c "ALTER USER $DB_USER WITH SUPERUSER;" 2>/dev/null || true
    
    success "Base de datos configurada"
}

configurar_prisma() {
    header "CONFIGURANDO PRISMA"
    
    if [ -f "prisma/schema.prisma" ]; then
        info "Generando cliente Prisma..."
        npx prisma generate
        
        info "Ejecutando migraciones..."
        if npx prisma migrate dev --name init 2>/dev/null; then
            success "Migraciones ejecutadas"
        else
            warning "Intentando método alternativo..."
            npx prisma db push 2>/dev/null && \
            success "Esquema aplicado" || \
            warning "No se pudieron aplicar migraciones"
        fi
    else
        warning "No se encontró schema.prisma - saltando Prisma"
    fi
}

instalar_dependencias() {
    header "INSTALANDO DEPENDENCIAS"
    
    if [ -f "package.json" ]; then
        info "Instalando paquetes Node.js..."
        npm install
        success "Dependencias instaladas"
    else
        error "No se encontró package.json"
        exit 1
    fi
}

verificar_seguridad() {
    header "VERIFICANDO SEGURIDAD"
    
    # Verificar que .env no esté en staging
    if git status --porcelain 2>/dev/null | grep -q "^[AM].*\.env$"; then
        error "PELIGRO: .env está en staging de Git"
        echo "Ejecuta: git reset .env"
    else
        success ".env no está en staging"
    fi
    
    # Verificar que .env esté en .gitignore
    if [ -f ".gitignore" ] && grep -q "^\.env$" .gitignore; then
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
    info "Sistema Honeypot - Equipo Decepticons"
    info "Repositorio: https://github.com/MartinCortes20/honeypotAuth-SystemEscom-DecepticonsEquipo8"
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
        warning "Configuración parcial - PostgreSQL no disponible"
        echo ""
        echo "Puedes continuar pero la aplicación no funcionará completamente."
        echo "Instala PostgreSQL y ejecuta:"
        echo "  npx prisma migrate dev"
        echo "  npm run dev"
    fi
    
    # 6. Verificar seguridad
    verificar_seguridad
    
    # 7. Resultado final
    header "✅ CONFIGURACION COMPLETADA"
    
    echo ""
    success "¡Proyecto configurado exitosamente!"
    echo ""
    echo "Para iniciar la aplicación:"
    echo "  ${BOLD}npm run dev${NC}"
    echo ""
    echo "La aplicación estará disponible en:"
    echo "  ${BOLD}http://localhost:3000${NC}"
    echo ""
    echo "Credenciales guardadas en: .env"
    echo ""
    echo "Si hay problemas:"
    echo "  1. Verifica que PostgreSQL esté corriendo"
    echo "  2. Revisa el archivo .env"
    echo "  3. Ejecuta: npx prisma migrate dev"
    echo ""
    echo "Soporte: Equipo Decepticons - ESCOM"
    echo "=========================================="
    echo ""
}

# Manejar errores
trap 'error "Error en línea $LINENO"; exit 1' ERR

# Ejecutar función principal
main