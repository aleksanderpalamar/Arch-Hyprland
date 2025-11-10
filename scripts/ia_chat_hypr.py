#!/usr/bin/env python3

import sys
import os
import json
import requests
import logging
from typing import Optional, Dict, List

from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QTextEdit, QLineEdit, QPushButton, QHBoxLayout, QLabel)
from PyQt5.QtCore import Qt, QTimer, QPropertyAnimation, QThread, pyqtSignal
from PyQt5.QtGui import QFont
from dotenv import load_dotenv

# ----- Logging Configuration -----
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# ----- Configuration -----
# Get script directory to find .env file
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, ".env")
HISTORY_FILE = os.path.expanduser("~/.config/hypr/scripts/ia_chat_history.json")
MAX_HISTORY_LENGTH = 20

# Load environment variables
if os.path.exists(ENV_FILE):
    logging.info(f"Carregando variáveis de ambiente de: {ENV_FILE}")
    load_dotenv(ENV_FILE)
else:
    logging.warning(f"Arquivo .env não encontrado: {ENV_FILE}")
    logging.warning(f"Crie o arquivo em: {ENV_FILE}")

API_KEY = os.getenv("AI_API_KEY", "").strip().strip('"').strip("'")
API_ENDPOINT = os.getenv("AI_API_ENDPOINT", "").strip().strip('"').strip("'")

# Debug logging
logging.info(f"API_KEY carregada: {'✓ Sim' if API_KEY else '✗ Não'}")
logging.info(f"API_ENDPOINT carregada: {'✓ Sim' if API_ENDPOINT else '✗ Não'}")
if API_ENDPOINT:
    logging.info(f"Endpoint detectado: {API_ENDPOINT[:50]}...")

# ----- IA Functions -----
def validate_config() -> bool:
    """Validate required configuration."""
    if not API_KEY:
        logging.error("AI_API_KEY está vazia ou não configurada no arquivo .env")
        logging.error(f"Verifique o arquivo: {ENV_FILE}")
        return False
    if not API_ENDPOINT:
        logging.error("AI_API_ENDPOINT está vazia ou não configurada no arquivo .env")
        logging.error(f"Verifique o arquivo: {ENV_FILE}")
        return False
    return True

def detect_provider(endpoint: str) -> str:
    """Detect API provider from endpoint URL."""
    endpoint_lower = endpoint.lower()
    if "openai" in endpoint_lower:
        return "openai"
    elif "gemini" in endpoint_lower:
        return "gemini"
    else:
        return "generic"

def get_ai_response(prompt: str) -> str:
    """Get AI response from the configured provider."""
    if not validate_config():
        return "[Erro]: Configuração da API inválida. Verifique o arquivo .env"
    
    provider = detect_provider(API_ENDPOINT)

    try:
        logging.info(f"Enviando requisição para {provider}...")
        
        if provider == "openai":
            headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
            payload = {"model": "gpt-4", "messages": [{"role": "user", "content": prompt}]}
            response = requests.post(API_ENDPOINT, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
            
        elif provider == "gemini":
            # Gemini usa API key na URL, não no header
            # Formato: https://generativelanguage.googleapis.com/v1/models/MODEL:generateContent
            headers = {"Content-Type": "application/json"}
            
            # Adicionar a key na URL
            url = f"{API_ENDPOINT}?key={API_KEY}"
            
            payload = {
                "contents": [{
                    "parts": [{"text": prompt}]
                }]
            }
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            data = response.json()
            return data["candidates"][0]["content"]["parts"][0]["text"]
            
        else:
            headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
            payload = {"prompt": prompt}
            response = requests.post(API_ENDPOINT, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            data = response.json()
            return data.get("text", str(data))
            
    except requests.exceptions.Timeout:
        logging.error("Timeout na requisição à API")
        return "[Erro]: Tempo esgotado ao conectar à API"
    except requests.exceptions.RequestException as e:
        logging.error(f"Erro na requisição: {e}")
        return f"[Erro ao conectar API]: {e}"
    except (KeyError, IndexError) as e:
        logging.error(f"Erro ao parsear resposta: {e}")
        return "[Erro]: Formato de resposta inesperado da API"

# ----- Functions context -----
def get_screen_context() -> str:
    """Get current screen context from Hyprland."""
    context = ""
    try:
        windows = os.popen("hyprctl clients -j 2>/dev/null").read()
        workspaces = os.popen("hyprctl activeworkspace -j 2>/dev/null").read()
        recent_files = os.popen("ls -lt ~/Documentos ~/Downloads 2>/dev/null | head -n 5").read()
        
        context += f"Janelas abertas:\n{windows[:500]}\n"  # Limitar tamanho
        context += f"\nWorkspace ativo:\n{workspaces[:300]}\n"
        context += f"\nArquivos recentes:\n{recent_files}"
    except Exception as e:
        logging.error(f"Erro ao obter contexto: {e}")
        context += f"[Erro ao obter contexto da tela]: {e}"
    return context

def load_history() -> List[Dict[str, str]]:
    """Load chat history from file."""
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            logging.error("Arquivo de histórico corrompido")
            return []
    return []

def save_history(history: List[Dict[str, str]]) -> None:
    """Save chat history to file, respecting MAX_HISTORY_LENGTH."""
    try:
        # Truncar histórico se exceder o limite
        if len(history) > MAX_HISTORY_LENGTH:
            history = history[-MAX_HISTORY_LENGTH:]
        
        os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
        with open(HISTORY_FILE, "w") as f:
            json.dump(history, f, indent=2)
    except Exception as e:
        logging.error(f"Erro ao salvar histórico: {e}")

# ---- Async Worker for API Calls -----
class AIWorker(QThread):
    """Worker thread for non-blocking API calls."""
    response_ready = pyqtSignal(str)
    
    def __init__(self, prompt: str):
        super().__init__()
        self.prompt = prompt
    
    def run(self):
        response = get_ai_response(self.prompt)
        self.response_ready.emit(response)

# ---- GUI Application -----
class ChatWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("IA Hyprland")
        self.setGeometry(100, 100, 700, 500)
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setStyleSheet("""
            QWidget {
                background-color: rgba(0, 0, 0, 0.85);
                color: white;
                font-size: 14px;
                border-radius: 10px;
            }
            QTextEdit {
                background-color: rgba(20, 20, 20, 0.9);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 5px;
                padding: 10px;
            }
            QLineEdit {
                background-color: rgba(40, 40, 40, 0.9);
                border: 1px solid rgba(255, 255, 255, 0.2);
                border-radius: 5px;
                padding: 8px;
            }
            QPushButton {
                background-color: rgba(60, 60, 60, 0.9);
                border: 1px solid rgba(255, 255, 255, 0.3);
                border-radius: 5px;
                padding: 8px 15px;
            }
            QPushButton:hover {
                background-color: rgba(80, 80, 80, 0.9);
            }
            QPushButton:pressed {
                background-color: rgba(40, 40, 40, 0.9);
            }
        """)

        self.worker = None
        self.layout = QVBoxLayout()
        self.setLayout(self.layout)

        # Header com botão fechar
        header_layout = QHBoxLayout()
        title_label = QLabel("🤖 IA Hyprland Assistant")
        title_label.setFont(QFont("Sans", 12, QFont.Bold))
        header_layout.addWidget(title_label)
        header_layout.addStretch()
        
        close_button = QPushButton("✕")
        close_button.setFixedSize(30, 30)
        close_button.clicked.connect(self.close)
        header_layout.addWidget(close_button)
        self.layout.addLayout(header_layout)

        # Chat display
        self.chat_display = QTextEdit()
        self.chat_display.setReadOnly(True)
        self.layout.addWidget(self.chat_display)

        # Status label
        self.status_label = QLabel("")
        self.status_label.setStyleSheet("color: #888; font-size: 12px;")
        self.layout.addWidget(self.status_label)

        # Input box
        self.input_box = QLineEdit()
        self.input_box.setPlaceholderText("Digite sua mensagem...")
        self.input_box.returnPressed.connect(self.send_message)
        self.layout.addWidget(self.input_box)

        # Botões de ação
        self.buttons_layout = QHBoxLayout()
        
        self.send_button = QPushButton("📤 Enviar")
        self.send_button.clicked.connect(self.send_message)
        self.buttons_layout.addWidget(self.send_button)

        self.context_button = QPushButton("🔄 Contexto")
        self.context_button.clicked.connect(self.show_context)
        self.buttons_layout.addWidget(self.context_button)

        self.terminal_button = QPushButton("💻 Terminal")
        self.terminal_button.clicked.connect(lambda: os.system("kitty &"))
        self.buttons_layout.addWidget(self.terminal_button)

        self.browser_button = QPushButton("🌐 Navegador")
        self.browser_button.clicked.connect(lambda: os.system("firefox &"))
        self.buttons_layout.addWidget(self.browser_button)

        self.clear_button = QPushButton("🗑️ Limpar")
        self.clear_button.clicked.connect(self.clear_history)
        self.buttons_layout.addWidget(self.clear_button)

        self.layout.addLayout(self.buttons_layout)

        # Histórico
        self.history = load_history()
        for item in self.history:
            self.chat_display.append(f"<b>{item['role']}:</b> {item['message']}")

        # Validar configuração
        if not validate_config():
            error_msg = f"""<span style='color: #ff5555;'><b>⚠️ Erro de Configuração:</b></span><br>
            As variáveis AI_API_KEY e/ou AI_API_ENDPOINT não estão configuradas.<br><br>
            <b>Arquivo:</b> <code>{ENV_FILE}</code><br><br>
            <b>Como configurar:</b><br>
            1. Abra o arquivo: <code>nano {ENV_FILE}</code><br>
            2. Adicione suas credenciais:<br>
            <code>AI_API_KEY=sua_chave_aqui</code><br>
            <code>AI_API_ENDPOINT=https://api.openai.com/v1/chat/completions</code><br>
            3. Salve e reinicie o aplicativo
            """
            self.chat_display.append(error_msg)

        # Animação fade-in
        self.animation = QPropertyAnimation(self, b"windowOpacity")
        self.animation.setDuration(400)
        self.animation.setStartValue(0)
        self.animation.setEndValue(1)
        self.animation.start()

    def send_message(self):
        """Send user message and get AI response."""
        user_msg = self.input_box.text().strip()
        if not user_msg or self.worker is not None:
            return
        
        self.chat_display.append(f"<b style='color: #4a9eff;'>Você:</b> {user_msg}")
        self.input_box.clear()
        self.send_button.setEnabled(False)
        self.status_label.setText("⏳ Aguardando resposta da IA...")

        context = get_screen_context()
        prompt = f"{context}\n\nUsuário disse: {user_msg}"

        # Usar thread para não bloquear UI
        self.worker = AIWorker(prompt)
        self.worker.response_ready.connect(self.handle_ai_response)
        self.worker.finished.connect(self.cleanup_worker)
        self.worker.start()

        # Salvar mensagem do usuário
        self.history.append({"role": "Você", "message": user_msg})

    def handle_ai_response(self, ai_msg: str):
        """Handle AI response."""
        self.chat_display.append(f"<b style='color: #50fa7b;'>IA:</b> {ai_msg}\n")
        self.status_label.setText("")
        
        self.history.append({"role": "IA", "message": ai_msg})
        save_history(self.history)

    def cleanup_worker(self):
        """Cleanup worker thread."""
        self.worker = None
        self.send_button.setEnabled(True)

    def show_context(self):
        """Show current screen context on demand."""
        self.status_label.setText("🔍 Carregando contexto...")
        context = get_screen_context()
        self.chat_display.append(f"<span style='color: #ffb86c;'><b>📋 Contexto Atual:</b></span>\n<pre>{context[:800]}</pre>\n")
        self.status_label.setText("")

    def clear_history(self):
        """Clear chat history."""
        self.history = []
        save_history(self.history)
        self.chat_display.clear()
        self.chat_display.append("<span style='color: #50fa7b;'>✅ Histórico limpo!</span>")

# ----- Initialization -----
if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = ChatWindow()
    window.show()
    sys.exit(app.exec_())