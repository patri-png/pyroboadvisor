#!/bin/bash
set -e

echo "🍎 Configurando compatibilidad para Safari/Mac..."
echo "================================================"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]  $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARN]  $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# 1. INSTALAR WEBSOCKIFY COMO ALTERNATIVA
log_info "Instalando websockify para mejor compatibilidad con Safari..."
pip3 install --user websockify

# 2. CREAR CONFIGURACIÓN ALTERNATIVA DE noVNC
log_info "Creando configuración optimizada para Safari..."

# Crear directorio para noVNC personalizado
mkdir -p ~/vnc-config

# Crear archivo HTML personalizado para Safari
cat > ~/vnc-config/vnc-safari.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IB Trading - VNC (Safari Optimized)</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
            color: #fff;
        }
        #vnc-container {
            width: 100vw;
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        #status-bar {
            background: #2a2a2a;
            padding: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #444;
        }
        #vnc-canvas-container {
            flex: 1;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
        }
        .status-indicator {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #666;
        }
        .status-dot.connected {
            background: #4CAF50;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        .control-buttons {
            display: flex;
            gap: 10px;
        }
        button {
            background: #3a3a3a;
            color: #fff;
            border: 1px solid #555;
            padding: 8px 16px;
            cursor: pointer;
            border-radius: 4px;
            transition: background 0.3s;
        }
        button:hover {
            background: #4a4a4a;
        }
        button:active {
            background: #2a2a2a;
        }
        #connection-dialog {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: #2a2a2a;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.5);
            z-index: 1000;
        }
        #connection-dialog h2 {
            margin-top: 0;
        }
        .hidden {
            display: none !important;
        }
        #error-message {
            background: #d32f2f;
            color: white;
            padding: 10px;
            border-radius: 4px;
            margin-top: 10px;
        }
        .safari-warning {
            background: #ff9800;
            color: #000;
            padding: 10px;
            margin: 10px 0;
            border-radius: 4px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div id="vnc-container">
        <div id="status-bar">
            <div class="status-indicator">
                <span class="status-dot" id="status-dot"></span>
                <span id="status-text">Disconnected</span>
            </div>
            <div class="control-buttons">
                <button onclick="toggleFullscreen()">Fullscreen</button>
                <button onclick="reconnect()">Reconnect</button>
                <button onclick="showKeyboard()">Keyboard</button>
            </div>
        </div>
        <div id="vnc-canvas-container">
            <canvas id="vnc-canvas"></canvas>
        </div>
    </div>

    <div id="connection-dialog">
        <h2>Connect to VNC Server</h2>
        <div class="safari-warning">
            ⚠️ Safari detected: For best experience, use Chrome or Firefox.
            If you must use Safari, disable "Prevent Cross-Site Tracking" in Settings.
        </div>
        <p>Host: <input type="text" id="host" value="localhost" readonly></p>
        <p>Port: <input type="text" id="port" value="5901" readonly></p>
        <p>Password: <input type="password" id="password" value="ibtrading"></p>
        <button onclick="connect()">Connect</button>
        <div id="error-message" class="hidden"></div>
    </div>

    <script>
        // Detectar Safari
        const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
        let rfb = null;

        // Configuración específica para Safari
        const safariConfig = {
            shared: true,
            viewOnly: false,
            focusOnClick: true,
            clipViewport: false,
            dragViewport: true,
            scaleViewport: false,
            resizeSession: false,
            showDotCursor: true,
            background: '#000000',
            qualityLevel: 6,
            compressionLevel: 2,
            wsProtocols: ['binary', 'base64']
        };

        // Configuración estándar
        const standardConfig = {
            shared: true,
            viewOnly: false,
            focusOnClick: true,
            clipViewport: true,
            dragViewport: true,
            scaleViewport: true,
            resizeSession: true,
            showDotCursor: false,
            background: '#000000',
            qualityLevel: 9,
            compressionLevel: 6
        };

        function connect() {
            const password = document.getElementById('password').value;
            const config = isSafari ? safariConfig : standardConfig;
            
            try {
                // Importar noVNC dinámicamente
                import('/novnc/core/rfb.js').then(module => {
                    const RFB = module.default;
                    
                    // URL de conexión
                    const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
                    const url = `${protocol}://${window.location.hostname}:6080/websockify`;
                    
                    // Crear conexión RFB
                    rfb = new RFB(
                        document.getElementById('vnc-canvas'),
                        url,
                        {
                            credentials: { password: password },
                            ...config
                        }
                    );
                    
                    // Event handlers
                    rfb.addEventListener('connect', () => {
                        console.log('Connected to VNC server');
                        document.getElementById('status-dot').classList.add('connected');
                        document.getElementById('status-text').textContent = 'Connected';
                        document.getElementById('connection-dialog').classList.add('hidden');
                    });
                    
                    rfb.addEventListener('disconnect', (e) => {
                        console.log('Disconnected from VNC server', e.detail);
                        document.getElementById('status-dot').classList.remove('connected');
                        document.getElementById('status-text').textContent = 'Disconnected';
                        
                        if (e.detail.clean) {
                            showError('Connection closed');
                        } else {
                            showError('Connection error: ' + (e.detail.reason || 'Unknown'));
                        }
                    });
                    
                    rfb.addEventListener('securityfailure', (e) => {
                        showError('Security failure: ' + e.detail.reason);
                    });
                    
                    // Safari-specific adjustments
                    if (isSafari) {
                        console.log('Applying Safari-specific optimizations...');
                        
                        // Deshabilitar características problemáticas en Safari
                        rfb.clipViewport = false;
                        rfb.scaleViewport = false;
                        rfb.resizeSession = false;
                        
                        // Ajustar calidad para mejor rendimiento
                        rfb.qualityLevel = 6;
                        rfb.compressionLevel = 2;
                    }
                    
                }).catch(err => {
                    showError('Failed to load noVNC: ' + err.message);
                    
                    // Fallback: intentar con websockify directo
                    console.log('Attempting websockify fallback...');
                    attemptWebsockifyConnection();
                });
                
            } catch (err) {
                showError('Connection failed: ' + err.message);
            }
        }

        function attemptWebsockifyConnection() {
            // Implementar conexión alternativa via websockify
            const ws = new WebSocket(`ws://${window.location.hostname}:6080/`);
            
            ws.onopen = () => {
                console.log('Websockify connection established');
                document.getElementById('status-text').textContent = 'Connected (Fallback)';
            };
            
            ws.onerror = (err) => {
                showError('Websockify connection failed');
            };
        }

        function reconnect() {
            if (rfb) {
                rfb.disconnect();
                rfb = null;
            }
            document.getElementById('connection-dialog').classList.remove('hidden');
            document.getElementById('error-message').classList.add('hidden');
        }

        function toggleFullscreen() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        }

        function showKeyboard() {
            // Crear input temporal para mostrar teclado móvil
            const input = document.createElement('input');
            input.type = 'text';
            input.style.position = 'absolute';
            input.style.left = '-9999px';
            document.body.appendChild(input);
            input.focus();
            setTimeout(() => {
                document.body.removeChild(input);
            }, 100);
        }

        function showError(message) {
            const errorEl = document.getElementById('error-message');
            errorEl.textContent = message;
            errorEl.classList.remove('hidden');
            document.getElementById('connection-dialog').classList.remove('hidden');
        }

        // Auto-connect si no es Safari
        window.addEventListener('load', () => {
            if (!isSafari) {
                setTimeout(() => {
                    console.log('Auto-connecting (non-Safari browser)...');
                    connect();
                }, 1000);
            } else {
                console.log('Safari detected - manual connection required');
            }
        });

        // Manejar reconexión en pérdida de foco (Safari issue)
        if (isSafari) {
            document.addEventListener('visibilitychange', () => {
                if (!document.hidden && rfb && rfb.connectionState === 'disconnected') {
                    console.log('Page visible again, attempting reconnection...');
                    reconnect();
                }
            });
        }
    </script>
</body>
</html>
EOF

# 3. CREAR SCRIPT DE INICIO ALTERNATIVO CON WEBSOCKIFY
cat > ~/vnc-config/start-websockify.sh << 'EOF'
#!/bin/bash
# Script para iniciar websockify como proxy para VNC

PORT_VNC=5901
PORT_WEB=6080

echo "Starting websockify bridge..."
websockify --web=/usr/share/novnc $PORT_WEB localhost:$PORT_VNC &
WEBSOCKIFY_PID=$!

echo "Websockify started with PID: $WEBSOCKIFY_PID"
echo "Access VNC at: http://localhost:$PORT_WEB/vnc.html"

# Guardar PID para poder detenerlo después
echo $WEBSOCKIFY_PID > ~/vnc-config/websockify.pid
EOF

chmod +x ~/vnc-config/start-websockify.sh

# 4. CREAR SCRIPT DE VERIFICACIÓN ESPECÍFICO PARA SAFARI
cat > ~/vnc-config/check-safari-compatibility.py << 'EOF'
#!/usr/bin/env python3
"""
Verificación de compatibilidad para Safari/Mac
"""

import sys
import os
import socket
import json
import subprocess
from pathlib import Path

class SafariCompatibilityChecker:
    def __init__(self):
        self.issues = []
        self.fixes_applied = []
        
    def check_websocket_support(self):
        """Verificar soporte de WebSocket"""
        try:
            import websocket
            self.fixes_applied.append("✅ WebSocket library available")
        except ImportError:
            self.issues.append("WebSocket library not installed")
            subprocess.run([sys.executable, "-m", "pip", "install", "--user", "websocket-client"])
            self.fixes_applied.append("✅ Installed websocket-client")
    
    def check_vnc_alternatives(self):
        """Verificar alternativas VNC disponibles"""
        vnc_servers = {
            'x11vnc': 'x11vnc -version',
            'tigervnc': 'vncserver -version',
            'tightvnc': 'tightvncserver -version'
        }
        
        available = []
        for server, cmd in vnc_servers.items():
            try:
                result = subprocess.run(cmd.split(), capture_output=True, text=True)
                if result.returncode == 0:
                    available.append(server)
            except:
                pass
        
        if available:
            self.fixes_applied.append(f"✅ Available VNC servers: {', '.join(available)}")
        else:
            self.issues.append("No alternative VNC servers found")
    
    def create_safari_config(self):
        """Crear configuración optimizada para Safari"""
        config = {
            "vnc": {
                "encoding": "tight",
                "quality": 6,
                "compression": 2,
                "shared": True,
                "view_only": False
            },
            "websocket": {
                "protocols": ["binary", "base64"],
                "timeout": 30,
                "ping_interval": 10
            },
            "display": {
                "resolution": "1440x900",
                "depth": 24,
                "dpi": 96
            }
        }
        
        config_path = Path.home() / "vnc-config" / "safari-settings.json"
        config_path.parent.mkdir(exist_ok=True)
        
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        self.fixes_applied.append(f"✅ Created Safari config: {config_path}")
    
    def setup_port_forwarding(self):
        """Configurar port forwarding alternativo"""
        script = """#!/bin/bash
# Port forwarding para Safari
socat TCP-LISTEN:8081,fork TCP:localhost:6080 &
echo "Alternative port 8081 -> 6080 forwarding started"
"""
        
        script_path = Path.home() / "vnc-config" / "port-forward.sh"
        with open(script_path, 'w') as f:
            f.write(script)
        
        os.chmod(script_path, 0o755)
        self.fixes_applied.append(f"✅ Created port forwarding script: {script_path}")
    
    def generate_report(self):
        """Generar reporte de compatibilidad"""
        print("\n" + "="*60)
        print("🍎 SAFARI COMPATIBILITY CHECK")
        print("="*60)
        
        if self.issues:
            print("\n⚠️ Issues Found:")
            for issue in self.issues:
                print(f"  • {issue}")
        
        if self.fixes_applied:
            print("\n✅ Fixes Applied:")
            for fix in self.fixes_applied:
                print(f"  • {fix}")
        
        print("\n📝 Safari-Specific Recommendations:")
        print("  1. Disable 'Prevent Cross-Site Tracking' in Safari Settings")
        print("  2. Allow pop-ups for localhost")
        print("  3. Use port 8081 if 6080 doesn't work")
        print("  4. Try Chrome or Firefox for best experience")
        
        print("\n🔗 Alternative Access Points:")
        print("  • Standard: http://localhost:6080")
        print("  • Safari-optimized: http://localhost:8081")
        print("  • Direct VNC: vnc://localhost:5901 (password: ibtrading)")
        
        print("="*60 + "\n")
    
    def run(self):
        """Ejecutar todas las verificaciones"""
        self.check_websocket_support()
        self.check_vnc_alternatives()
        self.create_safari_config()
        self.setup_port_forwarding()
        self.generate_report()

if __name__ == "__main__":
    checker = SafariCompatibilityChecker()
    checker.run()
EOF

chmod +x ~/vnc-config/check-safari-compatibility.py

# 5. EJECUTAR VERIFICACIÓN
log_info "Ejecutando verificación de compatibilidad..."
python3 ~/vnc-config/check-safari-compatibility.py

# 6. CREAR ALIAS ESPECÍFICOS PARA SAFARI
cat >> ~/.bashrc << 'EOF'

# 🍎 Safari/Mac specific aliases
alias vnc-safari='firefox ~/vnc-config/vnc-safari.html 2>/dev/null || open ~/vnc-config/vnc-safari.html 2>/dev/null || echo "Open http://localhost:6080 in your browser"'
alias start-websockify='~/vnc-config/start-websockify.sh'
alias check-safari='python3 ~/vnc-config/check-safari-compatibility.py'
alias vnc-alternative='echo "Try: vnc://localhost:5901 (password: ibtrading)"'

# Function to detect and suggest best VNC method
vnc-best() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "🍎 macOS detected. Best options:"
        echo "1. Direct VNC: vnc://localhost:5901"
        echo "2. Alternative web: http://localhost:8081"
        echo "3. Standard web: http://localhost:6080"
    else
        echo "🐧 Linux detected. Best options:"
        echo "1. Standard web: http://localhost:6080"
        echo "2. Direct VNC: vncviewer localhost:5901"
    fi
}

EOF

# 7. INSTALAR SERVIDOR HTTP ALTERNATIVO
log_info "Configurando servidor HTTP alternativo..."
cat > ~/vnc-config/simple-vnc-server.py << 'EOF'
#!/usr/bin/env python3
"""
Servidor HTTP simple para servir VNC optimizado para Safari
"""

import http.server
import socketserver
import os
from pathlib import Path

PORT = 8081
DIRECTORY = Path.home() / "vnc-config"

class SafariVNCHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIRECTORY), **kwargs)
    
    def end_headers(self):
        # Añadir headers para mejor compatibilidad con Safari
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

if __name__ == "__main__":
    os.chdir(DIRECTORY)
    with socketserver.TCPServer(("", PORT), SafariVNCHandler) as httpd:
        print(f"🌐 Safari-optimized VNC server at http://localhost:{PORT}")
        httpd.serve_forever()
EOF

chmod +x ~/vnc-config/simple-vnc-server.py

# 8. CREAR SERVICIO SYSTEMD (si es posible)
if command -v systemctl >/dev/null 2>&1; then
    log_info "Creando servicio systemd..."
    cat > ~/vnc-config/vnc-safari.service << EOF
[Unit]
Description=Safari-optimized VNC Web Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/vnc-config
ExecStart=/usr/bin/python3 $HOME/vnc-config/simple-vnc-server.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    log_info "Servicio creado (requiere activación manual con systemctl)"
else
    log_warning "systemd no disponible - usar scripts manuales"
fi

# 9. MENSAJE FINAL
log_success "✅ Configuración de compatibilidad Safari completada!"
echo ""
echo "🍎 INSTRUCCIONES PARA USUARIOS DE SAFARI/MAC:"
echo "=============================================="
echo ""
echo "1. OPCIÓN RECOMENDADA - VNC Nativo (macOS):"
echo "   • Abre Finder"
echo "   • Presiona Cmd+K"
echo "   • Ingresa: vnc://localhost:5901"
echo "   • Password: ibtrading"
echo ""
echo "2. OPCIÓN WEB - Safari Optimizado:"
echo "   • Ejecuta: start-websockify"
echo "   • Abre: http://localhost:8081"
echo ""
echo "3. OPCIÓN ESTÁNDAR (puede tener problemas):"
echo "   • Abre: http://localhost:6080"
echo ""
echo "⚠️ IMPORTANTE PARA SAFARI:"
echo "   • Desactiva 'Prevent Cross-Site Tracking'"
echo "   • Permite pop-ups para localhost"
echo "   • Si hay problemas, usa Chrome o Firefox"
echo ""
echo "📝 Comandos útiles:"
echo "   • check-safari    - Verificar compatibilidad"
echo "   • vnc-best       - Sugerir mejor método"
echo "   • vnc-safari     - Abrir página optimizada"
echo ""
log_info "Script completado. Reinicia el terminal para activar los alias."