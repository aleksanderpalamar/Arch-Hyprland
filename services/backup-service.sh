#!/bin/bash

# Backup Service - Sistema completo de backup e restore
# Gerencia backups com versionamento, integridade e agendamento

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do Backup Service
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups"
BACKUP_CONFIG="$PROJECT_ROOT/config/backup.conf"
BACKUP_INDEX="$BACKUP_DIR/backup_index.db"
TEMP_DIR="/tmp/hypr-backup-$$"

# Configurações padrão
DEFAULT_RETENTION_DAYS=30
DEFAULT_MAX_BACKUPS=10
DEFAULT_COMPRESSION=true
DEFAULT_SCHEDULE="daily"

# Estado do serviço
is_initialized=false
backup_schedule_pid=""

# Inicializar Backup Service
backup_service_init() {
    log_info "[BackupService] Inicializando Backup Service..."
    
    # Criar estrutura necessária
    backup_service_create_structure
    
    # Carregar configuração
    backup_service_load_config
    
    # Verificar integridade dos backups existentes
    backup_service_verify_existing_backups
    
    # Registrar handlers de eventos
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "system.shutdown" "backup_service_emergency_backup"
        register_event_handler "config.changed" "backup_service_auto_backup"
    fi
    
    is_initialized=true
    log_info "[BackupService] Backup Service inicializado"
    return 0
}

# Criar estrutura necessária
backup_service_create_structure() {
    mkdir -p "$BACKUP_DIR"/{full,incremental,emergency}
    mkdir -p "$(dirname "$BACKUP_CONFIG")"
    mkdir -p "$TEMP_DIR"
    
    # Criar configuração padrão se não existir
    if [ ! -f "$BACKUP_CONFIG" ]; then
        backup_service_create_default_config
    fi
    
    # Criar índice de backups se não existir
    if [ ! -f "$BACKUP_INDEX" ]; then
        backup_service_create_backup_index
    fi
}

# Criar configuração padrão
backup_service_create_default_config() {
    cat > "$BACKUP_CONFIG" << EOF
# Backup Service Configuration

# Retenção de backups
RETENTION_DAYS=$DEFAULT_RETENTION_DAYS
MAX_BACKUPS=$DEFAULT_MAX_BACKUPS

# Compressão
ENABLE_COMPRESSION=$DEFAULT_COMPRESSION
COMPRESSION_LEVEL=6

# Agendamento
BACKUP_SCHEDULE=$DEFAULT_SCHEDULE
AUTO_BACKUP_ON_CHANGE=true

# Diretórios incluídos no backup
BACKUP_INCLUDES=(
    "components/"
    "config/"
    "themes/"
    "services/"
    "core/"
    "scripts/"
)

# Diretórios excluídos do backup
BACKUP_EXCLUDES=(
    "cache/"
    "logs/"
    "temp/"
    "*.tmp"
    ".git/"
)

# Validação de integridade
ENABLE_CHECKSUMS=true
VERIFY_ON_RESTORE=true

# Notificações
NOTIFY_ON_SUCCESS=true
NOTIFY_ON_FAILURE=true
EOF

    log_info "[BackupService] Configuração padrão criada"
}

# Criar índice de backups
backup_service_create_backup_index() {
    cat > "$BACKUP_INDEX" << 'EOF'
# Backup Index Database
# Format: TIMESTAMP|TYPE|SIZE|CHECKSUM|STATUS|DESCRIPTION
# Created on $(date)

EOF
    log_info "[BackupService] Índice de backups criado"
}

# Carregar configuração
backup_service_load_config() {
    if [ -f "$BACKUP_CONFIG" ]; then
        source "$BACKUP_CONFIG" 2>/dev/null || {
            log_error "[BackupService] Erro ao carregar configuração"
            return 1
        }
        log_info "[BackupService] Configuração carregada"
    else
        log_warn "[BackupService] Configuração não encontrada, usando valores padrão"
    fi
}

# Criar backup completo
backup_service_create_full_backup() {
    local backup_description="${1:-"Backup completo manual"}"
    local timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_name="full_backup_$timestamp"
    local backup_path="$BACKUP_DIR/full/$backup_name"
    
    log_info "[BackupService] Criando backup completo: $backup_name"
    
    # Criar diretório do backup
    mkdir -p "$backup_path"
    
    # Criar arquivo de metadados
    cat > "$backup_path/metadata.json" << EOF
{
    "type": "full",
    "timestamp": "$timestamp",
    "description": "$backup_description",
    "created_by": "$(whoami)",
    "hostname": "$(hostname)",
    "project_version": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    # Fazer backup de cada diretório incluído
    local total_size=0
    for include_path in "${BACKUP_INCLUDES[@]}"; do
        if [ -e "$PROJECT_ROOT/$include_path" ]; then
            log_info "[BackupService] Fazendo backup de: $include_path"
            
            # Criar estrutura de diretório no backup
            local backup_target="$backup_path/$include_path"
            mkdir -p "$(dirname "$backup_target")"
            
            # Copiar com exclusões
            backup_service_copy_with_exclusions "$PROJECT_ROOT/$include_path" "$backup_target"
            
            # Calcular tamanho
            local dir_size="$(du -sb "$backup_target" 2>/dev/null | cut -f1)"
            total_size=$((total_size + dir_size))
        fi
    done
    
    # Comprimir se habilitado
    local final_backup_file="$backup_path"
    if [ "$ENABLE_COMPRESSION" = true ]; then
        log_info "[BackupService] Comprimindo backup..."
        local compressed_file="$BACKUP_DIR/full/$backup_name.tar.gz"
        
        tar -czf "$compressed_file" -C "$BACKUP_DIR/full" "$backup_name" && {
            rm -rf "$backup_path"
            final_backup_file="$compressed_file"
        }
    fi
    
    # Calcular checksum se habilitado
    local checksum=""
    if [ "$ENABLE_CHECKSUMS" = true ]; then
        checksum="$(sha256sum "$final_backup_file" | cut -d' ' -f1)"
    fi
    
    # Registrar no índice
    backup_service_register_backup "$timestamp" "full" "$total_size" "$checksum" "completed" "$backup_description"
    
    # Limpar backups antigos
    backup_service_cleanup_old_backups "full"
    
    log_info "[BackupService] Backup completo criado: $final_backup_file"
    
    # Notificar sucesso
    if [ "$NOTIFY_ON_SUCCESS" = true ]; then
        backup_service_notify "Backup completo criado com sucesso" "$backup_name"
    fi
    
    return 0
}

# Copiar com exclusões
backup_service_copy_with_exclusions() {
    local source="$1"
    local target="$2"
    
    # Construir padrões de exclusão para rsync
    local exclude_args=()
    for exclude_pattern in "${BACKUP_EXCLUDES[@]}"; do
        exclude_args+=("--exclude=$exclude_pattern")
    done
    
    # Usar rsync para cópia eficiente com exclusões
    if command -v rsync >/dev/null 2>&1; then
        rsync -a "${exclude_args[@]}" "$source" "$target"
    else
        # Fallback para cp
        cp -r "$source" "$target"
        
        # Remover exclusões manualmente
        for exclude_pattern in "${BACKUP_EXCLUDES[@]}"; do
            find "$target" -name "$exclude_pattern" -exec rm -rf {} + 2>/dev/null || true
        done
    fi
}

# Registrar backup no índice
backup_service_register_backup() {
    local timestamp="$1"
    local type="$2"
    local size="$3"
    local checksum="$4"
    local status="$5"
    local description="$6"
    
    echo "$timestamp|$type|$size|$checksum|$status|$description" >> "$BACKUP_INDEX"
}

# Listar backups disponíveis
backup_service_list_backups() {
    echo "=================================="
    echo "     BACKUPS DISPONÍVEIS"
    echo "=================================="
    echo ""
    
    if [ ! -f "$BACKUP_INDEX" ]; then
        echo "Nenhum backup encontrado"
        return 0
    fi
    
    # Ler índice e exibir backups
    while IFS='|' read -r timestamp type size checksum status description; do
        # Pular comentários e linhas vazias
        [[ "$timestamp" =~ ^#.*$ ]] || [[ -z "$timestamp" ]] && continue
        
        local human_size="$(backup_service_format_size "$size")"
        local human_date="$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" 2>/dev/null || echo "$timestamp")"
        
        echo "📦 $timestamp ($type)"
        echo "   📅 Data: $human_date"
        echo "   📊 Tamanho: $human_size"
        echo "   ✅ Status: $status"
        echo "   📝 Descrição: $description"
        
        if [ -n "$checksum" ] && [ "$checksum" != "N/A" ]; then
            echo "   🔒 Checksum: ${checksum:0:16}..."
        fi
        
        echo ""
    done < "$BACKUP_INDEX"
}

# Formatar tamanho em bytes para humano
backup_service_format_size() {
    local size="$1"
    
    if [ "$size" -gt 1073741824 ]; then
        echo "$(( size / 1073741824 ))GB"
    elif [ "$size" -gt 1048576 ]; then
        echo "$(( size / 1048576 ))MB"
    elif [ "$size" -gt 1024 ]; then
        echo "$(( size / 1024 ))KB"
    else
        echo "${size}B"
    fi
}

# Restaurar backup
backup_service_restore_backup() {
    local backup_timestamp="$1"
    local target_dir="${2:-$PROJECT_ROOT}"
    
    if [ -z "$backup_timestamp" ]; then
        log_error "[BackupService] Timestamp do backup é obrigatório"
        return 1
    fi
    
    log_info "[BackupService] Iniciando restore do backup: $backup_timestamp"
    
    # Encontrar backup
    local backup_info
    backup_info="$(grep "^$backup_timestamp|" "$BACKUP_INDEX" 2>/dev/null)"
    
    if [ -z "$backup_info" ]; then
        log_error "[BackupService] Backup não encontrado: $backup_timestamp"
        return 1
    fi
    
    # Extrair informações do backup
    local type="$(echo "$backup_info" | cut -d'|' -f2)"
    local checksum="$(echo "$backup_info" | cut -d'|' -f4)"
    
    # Localizar arquivo do backup
    local backup_file
    if [ -f "$BACKUP_DIR/$type/${backup_timestamp}.tar.gz" ]; then
        backup_file="$BACKUP_DIR/$type/${backup_timestamp}.tar.gz"
    elif [ -d "$BACKUP_DIR/$type/$backup_timestamp" ]; then
        backup_file="$BACKUP_DIR/$type/$backup_timestamp"
    else
        log_error "[BackupService] Arquivo de backup não encontrado"
        return 1
    fi
    
    # Verificar integridade se habilitado
    if [ "$VERIFY_ON_RESTORE" = true ] && [ -n "$checksum" ] && [ "$checksum" != "N/A" ]; then
        log_info "[BackupService] Verificando integridade do backup..."
        local current_checksum="$(sha256sum "$backup_file" | cut -d' ' -f1)"
        
        if [ "$current_checksum" != "$checksum" ]; then
            log_error "[BackupService] Falha na verificação de integridade!"
            return 1
        fi
        
        log_info "[BackupService] Integridade verificada com sucesso"
    fi
    
    # Criar backup de segurança antes do restore
    log_info "[BackupService] Criando backup de segurança antes do restore..."
    backup_service_create_full_backup "Backup de segurança antes do restore"
    
    # Extrair/copiar backup
    if [[ "$backup_file" == *.tar.gz ]]; then
        log_info "[BackupService] Extraindo backup comprimido..."
        tar -xzf "$backup_file" -C "$target_dir" --strip-components=1
    else
        log_info "[BackupService] Copiando backup descomprimido..."
        cp -r "$backup_file"/* "$target_dir"/
    fi
    
    log_info "[BackupService] Restore concluído com sucesso"
    
    # Notificar sucesso
    if [ "$NOTIFY_ON_SUCCESS" = true ]; then
        backup_service_notify "Restore concluído com sucesso" "$backup_timestamp"
    fi
    
    return 0
}

# Verificar integridade dos backups existentes
backup_service_verify_existing_backups() {
    log_info "[BackupService] Verificando integridade dos backups existentes..."
    
    if [ ! -f "$BACKUP_INDEX" ]; then
        log_info "[BackupService] Nenhum backup para verificar"
        return 0
    fi
    
    local corrupted_count=0
    
    while IFS='|' read -r timestamp type size checksum status description; do
        # Pular comentários e linhas vazias
        [[ "$timestamp" =~ ^#.*$ ]] || [[ -z "$timestamp" ]] && continue
        
        # Verificar apenas se tem checksum
        if [ -n "$checksum" ] && [ "$checksum" != "N/A" ]; then
            local backup_file
            if [ -f "$BACKUP_DIR/$type/${timestamp}.tar.gz" ]; then
                backup_file="$BACKUP_DIR/$type/${timestamp}.tar.gz"
            elif [ -d "$BACKUP_DIR/$type/$timestamp" ]; then
                backup_file="$BACKUP_DIR/$type/$timestamp"
            else
                log_warn "[BackupService] Arquivo de backup não encontrado: $timestamp"
                continue
            fi
            
            local current_checksum="$(sha256sum "$backup_file" | cut -d' ' -f1)"
            if [ "$current_checksum" != "$checksum" ]; then
                log_error "[BackupService] Backup corrompido detectado: $timestamp"
                ((corrupted_count++))
            fi
        fi
    done < "$BACKUP_INDEX"
    
    if [ $corrupted_count -eq 0 ]; then
        log_info "[BackupService] Todos os backups estão íntegros"
    else
        log_warn "[BackupService] $corrupted_count backup(s) corrompido(s) detectado(s)"
    fi
    
    return $corrupted_count
}

# Limpar backups antigos
backup_service_cleanup_old_backups() {
    local backup_type="$1"
    
    log_info "[BackupService] Limpando backups antigos do tipo: $backup_type"
    
    # Contar backups do tipo especificado
    local backup_count="$(grep "|$backup_type|" "$BACKUP_INDEX" 2>/dev/null | wc -l)"
    
    if [ "$backup_count" -le "$MAX_BACKUPS" ]; then
        log_info "[BackupService] Número de backups dentro do limite ($backup_count/$MAX_BACKUPS)"
        return 0
    fi
    
    # Remover backups mais antigos
    local to_remove=$((backup_count - MAX_BACKUPS))
    log_info "[BackupService] Removendo $to_remove backup(s) antigo(s)"
    
    # Obter timestamps dos backups mais antigos
    local old_backups
    old_backups="$(grep "|$backup_type|" "$BACKUP_INDEX" | head -n "$to_remove" | cut -d'|' -f1)"
    
    while read -r old_timestamp; do
        [ -z "$old_timestamp" ] && continue
        
        log_info "[BackupService] Removendo backup: $old_timestamp"
        
        # Remover arquivos
        rm -rf "$BACKUP_DIR/$backup_type/$old_timestamp"*
        
        # Remover do índice
        grep -v "^$old_timestamp|" "$BACKUP_INDEX" > "$BACKUP_INDEX.tmp" && \
        mv "$BACKUP_INDEX.tmp" "$BACKUP_INDEX"
    done <<< "$old_backups"
}

# Auto backup em mudanças de configuração
backup_service_auto_backup() {
    local event_data="$1"
    
    if [ "$AUTO_BACKUP_ON_CHANGE" = true ]; then
        log_info "[BackupService] Mudança de configuração detectada, criando backup automático..."
        backup_service_create_full_backup "Backup automático por mudança de configuração"
    fi
}

# Backup de emergência
backup_service_emergency_backup() {
    log_info "[BackupService] Criando backup de emergência..."
    backup_service_create_full_backup "Backup de emergência - shutdown do sistema"
}

# Notificação
backup_service_notify() {
    local message="$1"
    local details="$2"
    
    # Usar notify-send se disponível
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Backup Service" "$message" -i "folder-download"
    fi
    
    log_info "[BackupService] $message ($details)"
}

# Status do Backup Service
backup_service_status() {
    echo "=================================="
    echo "    BACKUP SERVICE STATUS"
    echo "=================================="
    echo ""
    
    echo "🔧 Serviço:"
    echo "  - Status: $([ "$is_initialized" = true ] && echo "Inicializado" || echo "Não inicializado")"
    echo "  - Diretório: $BACKUP_DIR"
    echo "  - Configuração: $BACKUP_CONFIG"
    echo ""
    
    if [ -f "$BACKUP_CONFIG" ]; then
        source "$BACKUP_CONFIG" 2>/dev/null
        echo "⚙️ Configuração:"
        echo "  - Retenção: $RETENTION_DAYS dias"
        echo "  - Máximo de backups: $MAX_BACKUPS"
        echo "  - Compressão: $ENABLE_COMPRESSION"
        echo "  - Checksums: $ENABLE_CHECKSUMS"
        echo ""
    fi
    
    if [ -f "$BACKUP_INDEX" ]; then
        local total_backups="$(grep -v '^#\|^$' "$BACKUP_INDEX" | wc -l)"
        local full_backups="$(grep '|full|' "$BACKUP_INDEX" 2>/dev/null | wc -l)"
        
        echo "📊 Estatísticas:"
        echo "  - Total de backups: $total_backups"
        echo "  - Backups completos: $full_backups"
        
        if [ "$total_backups" -gt 0 ]; then
            local last_backup="$(tail -n 1 "$BACKUP_INDEX" | cut -d'|' -f1)"
            echo "  - Último backup: $last_backup"
        fi
    fi
    
    echo ""
}

# Health check
backup_service_health_check() {
    local health_issues=0
    
    # Verificar estrutura
    if [ ! -d "$BACKUP_DIR" ]; then
        ((health_issues++))
    fi
    
    if [ ! -f "$BACKUP_CONFIG" ]; then
        ((health_issues++))
    fi
    
    if [ ! -f "$BACKUP_INDEX" ]; then
        ((health_issues++))
    fi
    
    # Verificar se há pelo menos um backup
    if [ -f "$BACKUP_INDEX" ]; then
        local backup_count="$(grep -v '^#\|^$' "$BACKUP_INDEX" | wc -l)"
        if [ "$backup_count" -eq 0 ]; then
            ((health_issues++))
        fi
    fi
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return $health_issues
}

# Função principal
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            backup_service_init
            ;;
        "backup"|"create")
            backup_service_create_full_backup "$2"
            ;;
        "list")
            backup_service_list_backups
            ;;
        "restore")
            backup_service_restore_backup "$2" "$3"
            ;;
        "verify")
            backup_service_verify_existing_backups
            ;;
        "cleanup")
            backup_service_cleanup_old_backups "$2"
            ;;
        "status")
            backup_service_status
            ;;
        "health_check")
            backup_service_health_check
            ;;
        "help"|"-h"|"--help")
            echo "Backup Service Commands:"
            echo "  init                     - Inicializar serviço"
            echo "  backup [descrição]       - Criar backup completo"
            echo "  list                     - Listar backups disponíveis"
            echo "  restore <timestamp>      - Restaurar backup"
            echo "  verify                   - Verificar integridade"
            echo "  cleanup <tipo>           - Limpar backups antigos"
            echo "  status                   - Status do serviço"
            echo "  health_check             - Verificar saúde"
            ;;
        *)
            echo "Ação desconhecida: $action" >&2
            echo "Use 'help' para ver comandos disponíveis" >&2
            exit 1
            ;;
    esac
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi