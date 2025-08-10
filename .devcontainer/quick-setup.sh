#!/bin/bash
# quick-setup.sh - Configuración rápida y eficiente para PyRoboAdvisor
set -e

echo "🚀 Configuración Rápida de PyRoboAdvisor"
echo "========================================"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. INSTALAR DEPENDENCIAS ESENCIALES (solo lo necesario)
echo -e "${YELLOW}[1/5] Instalando dependencias del sistema...${NC}"
sudo apt-get update -qq
sudo apt-get install -y -qq \
    wget curl \
    xvfb x11vnc \
    netcat-openbsd \
    htop \
    --no-install-recommends

# 2. INSTALAR REQUIREMENTS DE PYTHON
echo -e "${YELLOW}[2/5] Instalando librerías Python...${NC}"

# Actualizar pip primero
python -m pip install --upgrade pip --quiet

# Instalar requirements del proyecto si existen
if [ -f "/workspaces/pyroboadvisor/requirements.txt" ]; then
    pip install -r /workspaces/pyroboadvisor/requirements.txt --quiet
fi

# Instalar driver requirements si existen
if [ -f "/workspaces/pyroboadvisor/driver/requirements.txt" ]; then
    pip install -r /workspaces/pyroboadvisor/driver/requirements.txt --quiet
fi

# Instalar librerías adicionales necesarias
pip install --quiet \
    yfinance \
    ib-insync \
    pandas \
    numpy \
    matplotlib \
    requests \
    websocket-client

# 3. CREAR ESTRUCTURA BÁSICA
echo -e "${YELLOW}[3/5] Creando estructura de directorios...${NC}"
mkdir -p ~/trading/{scripts,logs,config}
mkdir -p /workspace/.cache

# 4. DESCARGAR IB GATEWAY (solo si no existe)
echo -e "${YELLOW}[4/5] Configurando IB Gateway...${NC}"
if [ ! -d "$HOME/Jts" ]; then
    cd ~/trading
    if [ ! -f "ibgateway-installer.sh" ]; then
        wget -q https://download2.interactivebrokers.com/installers/ibgateway/stable-standalone/ibgateway-stable-standalone-linux-x64.sh \
            -O ibgateway-installer.sh
        chmod +x ibgateway-installer.sh
    fi
    
    # Instalación silenciosa
    echo -e "\n\ny\n$HOME/Jts\nn\n" | ./ibgateway-installer.sh -c >/dev/null 2>&1 || true
fi

# 5. CREAR SCRIPTS SIMPLES DE INICIO
echo -e "${YELLOW}[5/5] Creando scripts de inicio...${NC}"

# Script para iniciar display
cat > ~/trading/scripts/start-display.sh << 'EOF'
#!/bin/bash
export DISPLAY=:1

# Matar procesos anteriores
pkill -f "Xvfb :1" 2>/dev/null || true
pkill -x "x11vnc" 2>/dev/null || true

# Esperar
sleep 1

# Iniciar Xvfb
Xvfb :1 -screen 0 1280x720x24 -ac &
sleep 2

# Iniciar VNC
x11vnc -display :1 -bg -forever -nopw -quiet -listen localhost -xkb &

echo "✅ Display virtual iniciado en :1"
echo "📺 VNC disponible en puerto 5901"
echo "🌐 Web VNC en http://localhost:6080"
EOF

# Script para iniciar IB Gateway
cat > ~/trading/scripts/start-ib.sh << 'EOF'
#!/bin/bash
export DISPLAY=:1

# Buscar IB Gateway
IB_PATH=$(find ~/Jts -name "ibgateway" -type f 2>/dev/null | head -1)

if [ -z "$IB_PATH" ]; then
    echo "❌ IB Gateway no encontrado"
    exit 1
fi

cd $(dirname "$IB_PATH")
./ibgateway > ~/trading/logs/ibgateway.log 2>&1 &
echo "✅ IB Gateway iniciado (PID: $!)"
EOF

# Script todo-en-uno
cat > ~/trading/scripts/start-trading.sh << 'EOF'
#!/bin/bash
echo "🚀 Iniciando sistema de trading..."

# Iniciar display
bash ~/trading/scripts/start-display.sh

# Esperar un poco
sleep 3

# Iniciar IB Gateway
bash ~/trading/scripts/start-ib.sh

echo ""
echo "✅ Sistema listo!"
echo "📊 VNC: vnc://localhost:5901 (password: ibtrading)"
echo "🌐 Web: http://localhost:6080"
echo "🔌 API: localhost:4002"
EOF

# Hacer ejecutables
chmod +x ~/trading/scripts/*.sh

# 6. CREAR ALIASES
cat >> ~/.bashrc << 'EOF'

# PyRoboAdvisor aliases
alias start-trading='bash ~/trading/scripts/start-trading.sh'
alias start-display='bash ~/trading/scripts/start-display.sh'
alias start-ib='bash ~/trading/scripts/start-ib.sh'
alias check-ports='netstat -tlnp 2>/dev/null | grep -E "(6080|5901|4002)" || echo "No hay puertos activos"'
alias proyecto='cd /workspaces/pyroboadvisor'

# Activar automáticamente
export DISPLAY=:1
export PYTHONPATH=/workspaces/pyroboadvisor

EOF

# 7. VERIFICACIÓN RÁPIDA
echo ""
echo -e "${GREEN}✅ Configuración completada!${NC}"
echo ""
echo "Python: $(python --version)"
echo "Pip: $(pip --version)"

# Verificar librerías críticas
python -c "
import sys
libs = ['yfinance', 'ib_insync', 'pandas', 'numpy']
print('Librerías Python:')
for lib in libs:
    try:
        __import__(lib)
        print(f'  ✅ {lib}')
    except ImportError:
        print(f'  ❌ {lib}')
        sys.exit(1)
"

echo ""
echo -e "${GREEN}🎯 PRÓXIMOS PASOS:${NC}"
echo "1. Reinicia el terminal o ejecuta: source ~/.bashrc"
echo "2. Ejecuta: start-trading"
echo "3. Accede a: http://localhost:6080"
echo "4. Login en IB Gateway"
echo "5. Ejecuta: python sample.py"
echo ""
echo "📝 Comandos disponibles:"
echo "  start-trading  - Inicia todo el sistema"
echo "  start-display  - Solo display virtual"
echo "  start-ib      - Solo IB Gateway"
echo "  check-ports   - Verificar puertos"
echo ""