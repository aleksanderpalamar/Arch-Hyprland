# 🔒 Análise de Segurança - Arch-Hyprland

Este documento detalha as vulnerabilidades de segurança identificadas no projeto e suas respectivas soluções.

## 📋 Vulnerabilidades Identificadas

### 🚨 Críticas

#### 1. Injeção de Comando via Nomes de Arquivo

**Arquivo:** `hypr/scripts/SelectWallpaper.sh`  
**Linha:** 30-32  
**Risco:** Alto

**Problema:**

```bash
# Código vulnerável
selected_wallpaper=$(find . -maxdepth 1 -type f \( -iname "*.jpg" ... \) | rofi -dmenu)
hyprctl hyprpaper preload "$full_path"  # Sem validação
```

**Exploração Possível:**

```bash
# Arquivo malicioso: "wallpaper'; rm -rf ~; echo '.jpg"
# Resultado: comando rm é executado
```

**Solução:**

```bash
validate_filename() {
    local filename="$1"
    # Permitir apenas caracteres seguros
    if [[ "$filename" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        return 0
    fi
    return 1
}

# Uso seguro
if validate_filename "$selected_wallpaper"; then
    full_path="$WALLPAPER_DIR/$selected_wallpaper"
    hyprctl hyprpaper preload "$full_path"
else
    notify-send "Erro" "Nome de arquivo inválido"
    exit 1
fi
```

#### 2. Execução de Script Sem Validação de Integridade

**Arquivo:** `install.sh`  
**Linha:** Múltiplas  
**Risco:** Alto

**Problema:**

- Scripts são copiados e executados sem verificação de integridade
- Permissões são alteradas sem validação

**Solução:**

```bash
# Verificação de checksums
EXPECTED_CHECKSUMS="scripts/checksums.sha256"

verify_script_integrity() {
    local script_path="$1"
    if [[ -f "$EXPECTED_CHECKSUMS" ]]; then
        sha256sum -c "$EXPECTED_CHECKSUMS" | grep "$script_path"
        return $?
    fi
    return 1
}

# Aplicar permissões seguras
_set_permissions() {
    local script_dir="$HOME/.config/hypr/scripts"
    find "$script_dir" -name "*.sh" -type f | while read -r script; do
        if verify_script_integrity "$script"; then
            chmod 750 "$script"  # Mais restritivo que 755
        else
            log_error "Script failed integrity check: $script"
        fi
    done
}
```

### ⚠️ Moderadas

#### 3. Exposição de Informações Sensíveis em Logs

**Arquivo:** `hypr/scripts/WaybarScripts.sh`  
**Risco:** Médio

**Problema:**

```bash
# Configurações podem conter informações sensíveis
eval "$config_content"  # Sem sanitização
```

**Solução:**

```bash
# Sanitização segura
sanitize_config() {
    local config="$1"
    # Remover comandos potencialmente perigosos
    echo "$config" | sed 's/\$(\([^)]*\))//g' | sed 's/`\([^`]*\)`//g'
}

config_content=$(sanitize_config "$(sed 's/\$//g' "$config_file")")
```

#### 4. Falta de Validação em Downloads/Updates

**Arquivo:** `install.sh`  
**Risco:** Médio

**Solução:**

```bash
verify_package_signature() {
    local package="$1"
    # Verificar assinatura GPG
    gpg --verify "$package.sig" "$package" 2>/dev/null
    return $?
}

install_with_verification() {
    local package="$1"
    if verify_package_signature "$package"; then
        $AUR_HELPER -S --noconfirm "$package"
    else
        log_error "Package signature verification failed: $package"
        return 1
    fi
}
```

### ⚡ Baixas

#### 5. Permissões de Arquivo Muito Permissivas

**Arquivo:** `install.sh`  
**Risco:** Baixo

**Solução:**

```bash
# Definir umask restritivo
umask 0027

# Corrigir permissões após instalação
fix_permissions() {
    # Arquivos de configuração: somente leitura/escrita para usuário
    find "$HOME/.config/hypr" -type f -exec chmod 640 {} \;
    # Diretórios: acesso apenas para usuário e grupo
    find "$HOME/.config/hypr" -type d -exec chmod 750 {} \;
    # Scripts: executáveis apenas se necessário
    find "$HOME/.config/hypr/scripts" -name "*.sh" -exec chmod 750 {} \;
}
```

## 🛡️ Implementações de Segurança Recomendadas

### 1. Sistema de Logging de Segurança

```bash
# /home/palamar/Projetos-prod/Arch-Hyprland/hypr/scripts/security-logger.sh
#!/bin/bash

SECURITY_LOG="$HOME/.config/hypr/logs/security.log"
mkdir -p "$(dirname "$SECURITY_LOG")"

log_security_event() {
    local event_type="$1"
    local details="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SECURITY [$event_type] $details" >> "$SECURITY_LOG"
}

# Exemplos de uso
log_security_event "WALLPAPER_CHANGE" "User changed wallpaper to: $wallpaper_name"
log_security_event "SCRIPT_EXECUTION" "Script executed: $script_name by PID: $$"
log_security_event "CONFIG_MODIFICATION" "Configuration file modified: $config_file"
```

### 2. Validador de Configuração

```bash
# /home/palamar/Projetos-prod/Arch-Hyprland/hypr/scripts/config-validator.sh
#!/bin/bash

validate_hypr_config() {
    local config_file="$1"

    # Verificar sintaxe básica
    if ! hyprctl --batch "$(cat "$config_file")" 2>/dev/null; then
        return 1
    fi

    # Verificar comandos perigosos
    if grep -E "(rm|dd|mkfs|format)" "$config_file"; then
        log_security_event "DANGEROUS_CONFIG" "Dangerous commands found in $config_file"
        return 1
    fi

    # Verificar paths seguros
    if grep -E "/(etc|usr/bin|boot)" "$config_file"; then
        log_security_event "SYSTEM_PATH_ACCESS" "System paths found in $config_file"
        return 1
    fi

    return 0
}
```

### 3. Sandbox para Scripts

```bash
# Executar scripts em ambiente controlado
run_script_safely() {
    local script="$1"
    local allowed_dirs="$HOME/.config/hypr:$HOME/Imagens"

    # Usar firejail se disponível
    if command -v firejail >/dev/null; then
        firejail --whitelist="$allowed_dirs" --noroot "$script"
    else
        # Fallback: verificações básicas
        if validate_script_safety "$script"; then
            "$script"
        else
            log_security_event "UNSAFE_SCRIPT" "Script blocked: $script"
            return 1
        fi
    fi
}
```

### 4. Verificação de Integridade de Arquivos

```bash
# Gerar checksums durante instalação
generate_checksums() {
    local config_dir="$HOME/.config/hypr"
    local checksum_file="$config_dir/integrity.sha256"

    find "$config_dir" -type f -name "*.conf" -o -name "*.sh" | \
        xargs sha256sum > "$checksum_file"

    # Proteger o arquivo de checksums
    chmod 400 "$checksum_file"
}

# Verificar integridade periodicamente
check_integrity() {
    local config_dir="$HOME/.config/hypr"
    local checksum_file="$config_dir/integrity.sha256"

    if [[ -f "$checksum_file" ]]; then
        if ! sha256sum -c "$checksum_file" --quiet; then
            log_security_event "INTEGRITY_VIOLATION" "Configuration files modified unexpectedly"
            notify-send "Atenção" "Arquivos de configuração foram modificados"
            return 1
        fi
    fi
    return 0
}
```

## 🔐 Hardening Adicional

### 1. AppArmor Profile (Opcional)

```bash
# /etc/apparmor.d/hyprland-config
#include <tunables/global>

profile hyprland-config flags=(attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/user-tmp>

  # Permitir acesso apenas aos diretórios necessários
  owner @{HOME}/.config/hypr/ r,
  owner @{HOME}/.config/hypr/** rwk,
  owner @{HOME}/Imagens/wallpapers/ r,
  owner @{HOME}/Imagens/wallpapers/** r,

  # Negar acesso a diretórios sensíveis
  deny /etc/ r,
  deny /usr/bin/ w,
  deny /boot/ rwklx,

  # Permitir executáveis necessários
  /usr/bin/hyprctl rix,
  /usr/bin/notify-send rix,
  /usr/bin/rofi rix,
}
```

### 2. Systemd Service com Isolamento

```ini
# ~/.config/systemd/user/hyprland-security.service
[Unit]
Description=Hyprland Security Monitor
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.config/hypr/scripts/security-monitor.sh
Restart=always
RestartSec=10

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
ReadWritePaths=%h/.config/hypr/logs

[Install]
WantedBy=default.target
```

### 3. Configuração Segura de Backup

```bash
# Backup criptografado
create_secure_backup() {
    local backup_dir="$HOME/.config/hypr/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/config_$timestamp.tar.gz.gpg"

    mkdir -p "$backup_dir"

    # Criar arquivo compactado
    tar -czf - -C "$HOME/.config" hypr | \
        gpg --symmetric --cipher-algo AES256 --compress-algo 2 \
            --output "$backup_file"

    # Limpar backups antigos (manter apenas 10)
    ls -t "$backup_dir"/config_*.tar.gz.gpg | tail -n +11 | xargs -r rm
}
```

## 📝 Checklist de Segurança

### Para Desenvolvedores

- [ ] Todos os inputs são validados
- [ ] Não há execução de código arbitrário
- [ ] Logs não contêm informações sensíveis
- [ ] Permissões de arquivo são mínimas necessárias
- [ ] Checksums são verificados antes da execução
- [ ] Configurações são validadas antes da aplicação

### Para Usuários

- [ ] Verificar integridade dos arquivos baixados
- [ ] Revisar scripts antes da execução
- [ ] Manter backups seguros das configurações
- [ ] Monitorar logs de segurança regularmente
- [ ] Atualizar o sistema regularmente
- [ ] Usar senhas fortes para criptografia

### Para Auditores

- [ ] Revisar todos os scripts quanto a vulnerabilidades
- [ ] Testar injeção de comandos
- [ ] Verificar escalada de privilégios
- [ ] Avaliar exposição de dados
- [ ] Testar bypass de validações
- [ ] Verificar configurações de permissões

## 🚀 Implementação Gradual

### Fase 1 (Imediata)

1. Corrigir injeção de comandos em `SelectWallpaper.sh`
2. Adicionar validação básica em todos os scripts
3. Implementar logging de segurança

### Fase 2 (Curto Prazo)

1. Sistema de checksums
2. Validador de configuração
3. Permissões mais restritivas

### Fase 3 (Médio Prazo)

1. Sandbox para scripts
2. AppArmor profiles
3. Backup criptografado

### Fase 4 (Longo Prazo)

1. Integração com sistemas de segurança externos
2. Auditoria automática
3. Alertas em tempo real

---

_A segurança é um processo contínuo. Este documento deve ser revisado e atualizado regularmente conforme novas ameaças são identificadas._
