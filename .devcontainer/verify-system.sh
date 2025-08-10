#!/bin/bash
# verify-system.sh - Verificación completa del sistema PyRoboAdvisor

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Funciones de logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

# Variables de estado
ERRORS=0
WARNINGS=0
SUCCESS=0

# Header
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║       🔍 PyRoboAdvisor System Verification v2.0            ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Función para verificar comando
check_command() {
    local cmd=$1
    local name=$2
    if command -v $cmd >/dev/null 2>&1; then
        log_success "$name disponible: $(which $cmd)"
        ((SUCCESS++))
        return 0
    else
        log_error "$name NO encontrado"
        ((ERRORS++))
        return 1
    fi
}

# Función para verificar puerto
check_port() {
    local port=$1
    local service=$2
    local required=$3
    
    if nc -z -w1 localhost $port 2>/dev/null; then
        log_success "Puerto $port ($service) - ABIERTO"
        ((SUCCESS++))
        return 0
    else
        if [ "$required" = "required" ]; then
            log_error "Puerto $port ($service) - CERRADO (REQUERIDO)"
            ((ERRORS++))
        else
            log_warning "Puerto $port ($service) - CERRADO (opcional)"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Función para verificar proceso
check_process() {
    local process=$1
    local name=$2
    
    if pgrep -f "$process" > /dev/null 2>&1; then
        local pid=$(pgrep -f "$process" | head -1)
        log_success "$name ejecutándose (PID: $pid)"
        ((SUCCESS++))
        return 0
    else
        log_warning "$name NO detectado"
        ((WARNINGS++))
        return 1
    fi
}

# Función para verificar Python library
check_python_lib() {
    local lib=$1
    local required=$2
    
    if python3 -c "import $lib" 2>/dev/null; then
        local version=$(python3 -c "import $lib; print(getattr($lib, '__version__', 'installed'))" 2>/dev/null || echo "installed")
        log_success "Python lib: $lib ($version)"
        ((SUCCESS++))
        return 0
    else
        if [ "$required" = "required" ]; then
            log_error "Python lib: $lib - NO INSTALADA (REQUERIDA)"
            ((ERRORS++))
        else
            log_warning "Python lib: $lib - NO INSTALADA (opcional)"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Función para verificar archivo/directorio
check_path() {
    local path=$1
    local type=$2
    local name=$3
    
    if [ "$type" = "file" ] && [ -f "$path" ]; then
        log_success "$name encontrado: $path"
        ((SUCCESS++))
        return 0
    elif [ "$type" = "dir" ] && [ -d "$path" ]; then
        log_success "$name encontrado: $path"
        ((SUCCESS++))
        return 0
    else
        log_warning "$name NO encontrado: $path"
        ((WARNINGS++))
        return 1
    fi
}

# ============================================
# VERIFICACIONES DEL SISTEMA
# ============================================

echo -e "${CYAN}═══ 1. Sistema Operativo ═══${NC}"
echo "OS: $(uname -s) $(uname -r)"
echo "Arquitectura: $(uname -m)"
echo "Usuario: $USER"
echo "Home: $HOME"
echo "PWD: $(pwd)"
echo ""

echo -e "${CYAN}═══ 2. Comandos del Sistema ═══${NC}"
check_command "python3" "Python 3"
check_command "pip3" "Pip 3"
check_command "java" "Java"
check_command "git" "Git"
check_command "curl" "Curl"
check_command "nc" "Netcat"
check_command "xvfb-run" "Xvfb"
check_command "x11vnc" "X11VNC"
echo ""

echo -e "${CYAN}═══ 3. Versiones ═══${NC}"
if command -v python3 >/dev/null 2>&1; then
    echo "Python: $(python3 --version)"
fi
if command -v java >/dev/null 2>&1; then
    echo "Java: $(java -version 2>&1 | head -1)"
fi
if command -v node >/dev/null 2>&1; then
    echo "Node: $(node --version)"
fi
echo ""

echo -e "${CYAN}═══ 4. Display Virtual ═══${NC}"
if [ -n "$DISPLAY" ]; then
    log_success "DISPLAY configurado: $DISPLAY"
    ((SUCCESS++))
else
    log_error "DISPLAY no configurado"
    ((ERRORS++))
fi
check_process "Xvfb" "Xvfb"
check_process "x11vnc" "VNC Server"
echo ""

echo -e "${CYAN}═══ 5. Puertos de Red ═══${NC}"
check_port 6080 "noVNC Web" "optional"
check_port 5901 "VNC Server" "optional"
check_port 4002 "IB Gateway Paper API" "optional"
check_port 4001 "IB Gateway Live API" "optional"
check_port 8080 "Trading Dashboard" "optional"
check_port 8081 "Alternative VNC" "optional"
echo ""

echo -e "${CYAN}═══ 6. Interactive Brokers ═══${NC}"
check_process "ibgateway" "IB Gateway"
check_path "$HOME/Jts" "dir" "IB Gateway Installation"
check_path "$HOME/trading" "dir" "Trading Directory"
echo ""

echo -e "${CYAN}═══ 7. Python Libraries (Requeridas) ═══${NC}"
check_python_lib "yfinance" "required"
check_python_lib "pandas" "required"
check_python_lib "numpy" "required"
check_python_lib "requests" "required"
echo ""

echo -e "${CYAN}═══ 8. Python Libraries (IB Trading) ═══${NC}"
check_python_lib "ib_insync" "required"
check_python_lib "matplotlib" "optional"
check_python_lib "scipy" "optional"
check_python_lib "plotly" "optional"
echo ""

echo -e "${CYAN}═══ 9. Archivos del Proyecto ═══${NC}"
WORKSPACE="/workspaces/pyroboadvisor"
if [ ! -d "$WORKSPACE" ]; then
    WORKSPACE="/workspace"
fi
if [ ! -d "$WORKSPACE" ]; then
    WORKSPACE="$(pwd)"
fi

check_path "$WORKSPACE/sample.py" "file" "Script principal"
check_path "$WORKSPACE/strategyClient.py" "file" "Cliente estrategia"
check_path "$WORKSPACE/driver/driverIB.py" "file" "Driver IB"
check_path "$WORKSPACE/market/source.py" "file" "Source module"
check_path "$WORKSPACE/requirements.txt" "file" "Requirements"
echo ""

echo -e "${CYAN}═══ 10. Caché y Datos ═══${NC}"
# Verificar múltiples ubicaciones de caché
CACHE_FOUND=false
for cache_dir in "$WORKSPACE/cache" "$WORKSPACE/../cache" "$HOME/.cache"; do
    if [ -d "$cache_dir" ]; then
        log_success "Cache encontrado: $cache_dir"
        if [ -w "$cache_dir" ]; then
            log_success "Cache escribible"
        else
            log_warning "Cache NO escribible"
        fi
        CACHE_FOUND=true
        ((SUCCESS++))
        break
    fi
done

if [ "$CACHE_FOUND" = false ]; then
    log_warning "Directorio cache no encontrado (se creará automáticamente)"
    ((WARNINGS++))
fi
echo ""

echo -e "${CYAN}═══ 11. Conectividad ═══${NC}"
# Verificar conexión a Internet
if ping -c 1 google.com >/dev/null 2>&1; then
    log_success "Conexión a Internet OK"
    ((SUCCESS++))
else
    log_error "Sin conexión a Internet"
    ((ERRORS++))
fi

# Verificar API de PyRoboAdvisor
if curl -s -o /dev/null -w "%{http_code}" https://pyroboadvisor.org | grep -q "200\|301\|302"; then
    log_success "API PyRoboAdvisor accesible"
    ((SUCCESS++))
else
    log_warning "API PyRoboAdvisor no accesible"
    ((WARNINGS++))
fi
echo ""

echo -e "${CYAN}═══ 12. Configuración Específica del Navegador ═══${NC}"
# Detectar si estamos en un entorno con navegador
if [ -n "$HTTP_USER_AGENT" ]; then
    echo "User Agent detectado: $HTTP_USER_AGENT"
    if echo "$HTTP_USER_AGENT" | grep -qi "safari"; then
        log_warning "Safari detectado - Ver instrucciones especiales"
        echo "  Ejecuta: check-safari"
        ((WARNINGS++))
    fi
else
    log_info "No se detectó navegador (ejecución desde terminal)"
fi
echo ""

# ============================================
# RESUMEN Y RECOMENDACIONES
# ============================================

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                     📊 RESUMEN                              ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ Éxitos:${NC} $SUCCESS"
echo -e "  ${YELLOW}⚠ Advertencias:${NC} $WARNINGS"
echo -e "  ${RED}✗ Errores:${NC} $ERRORS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✅ SISTEMA LISTO PARA TRADING                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "🎯 Próximos pasos:"
    echo "  1. Ejecuta: start-trading"
    echo "  2. Accede a: http://localhost:6080"
    echo "  3. Login en IB Gateway"
    echo "  4. Ejecuta: python3 sample.py"
elif [ $ERRORS -lt 3 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     ⚠️ SISTEMA PARCIALMENTE CONFIGURADO                     ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📝 Acciones recomendadas:"
    
    # Recomendaciones específicas basadas en errores
    if ! check_python_lib "ib_insync" "quiet" 2>/dev/null; then
        echo "  • Instalar ib_insync: pip3 install --user ib_insync"
    fi
    
    if ! pgrep -f "Xvfb" > /dev/null 2>&1; then
        echo "  • Iniciar display: start-display"
    fi
    
    if ! pgrep -f "ibgateway" > /dev/null 2>&1; then
        echo "  • Iniciar IB Gateway: start-ib"
    fi
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     ❌ SISTEMA REQUIERE CONFIGURACIÓN                       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "🔧 Ejecuta los siguientes comandos:"
    echo "  1. bash .devcontainer/complete-setup.sh"
    echo "  2. source ~/.bashrc"
    echo "  3. start-trading"
fi

echo ""
echo "📚 Documentación: ~/trading/COMANDOS.md"
echo "🔍 Para más detalles: check-system"
echo ""

# Guardar resultado en archivo
REPORT_FILE="$HOME/trading/logs/system-check-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$HOME/trading/logs"
{
    echo "System Verification Report - $(date)"
    echo "Success: $SUCCESS"
    echo "Warnings: $WARNINGS"
    echo "Errors: $ERRORS"
} > "$REPORT_FILE"

log_info "Reporte guardado en: $REPORT_FILE"

# Exit con código apropiado
if [ $ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi