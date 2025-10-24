# 📚 Documentação - Arch-Hyprland

Documentação completa para instalação, uso e personalização do ambiente Hyprland.

## 🚀 Começando

### Instalação Rápida

```bash
# Clone o repositório
git clone https://github.com/aleksanderpalamar/Arch-Hyprland.git
cd Arch-Hyprland

# Execute a instalação
./install.sh
```

### Primeiro Uso

Após a instalação:

1. **Faça logout** do desktop atual
2. **Selecione "Hyprland"** no display manager
3. **Use Super + Enter** para abrir o terminal

## 📖 Guias Principais

### Para Usuários

- **[📖 Guia do Usuário](USER_GUIDE.md)** - Como usar e personalizar o sistema
  - Atalhos de teclado essenciais
  - Como personalizar wallpapers e temas
  - Configuração de monitores
  - Solução de problemas comuns

### Para Desenvolvedores

- **[🏗️ Arquitetura](architecture/ARCHITECTURE.md)** - Como o sistema funciona internamente
- **[📋 API Reference](api/API.md)** - APIs para criar componentes e plugins

## 🎯 Casos de Uso Comuns

### 🖼️ Personalização Visual

- **Alterar Wallpaper**: `Super + W` → Selecionar nova imagem
- **Trocar Tema**: Modifique arquivos em `~/.config/hypr/UserConfigs/`
- **Configurar Waybar**: Edite `~/.config/waybar/config.jsonc`

### ⌨️ Atalhos Essenciais

| Atalho                | Ação                        |
| --------------------- | --------------------------- |
| `Super + Enter`       | Terminal                    |
| `Super + Q`           | Fechar janela               |
| `Super + R`           | Menu de aplicações          |
| `Super + W`           | Seletor de wallpapers       |
| `Super + 1-9`         | Trocar workspace            |
| `Super + Shift + 1-9` | Mover janela para workspace |

### 🔧 Configurações Rápidas

```bash
# Recarregar configuração do Hyprland
hyprctl reload

# Recarregar Waybar
killall waybar && waybar &

# Aplicar novo wallpaper
~/.config/hypr/scripts/SelectWallpaper.sh
```

## 🆘 Problemas Comuns

### Hyprland não inicia

```bash
# Verificar logs
journalctl -u display-manager
# ou
~/.local/share/hyprland/hyprland.log
```

### Waybar não aparece

```bash
# Restartar waybar
killall waybar
waybar &
```

### Sem áudio

```bash
# Verificar PipeWire
systemctl --user status pipewire
systemctl --user restart pipewire
```

## 📁 Estrutura de Arquivos

```
~/.config/hypr/          # Configurações principais
├── hyprland.conf        # Configuração principal
├── UserConfigs/         # Suas personalizações
├── scripts/             # Scripts de automação
└── ...

~/.config/waybar/        # Barra superior
~/.config/rofi/          # Menu de aplicações
~/Imagens/wallpapers/    # Seus wallpapers
```

## 🔄 Atualizações

```bash
# Atualizar o sistema
cd /path/to/Arch-Hyprland
git pull
./install.sh
```

## 📞 Suporte

- **Issues**: [GitHub Issues](https://github.com/aleksanderpalamar/Arch-Hyprland/issues)
- **Documentação**: Consulte os guias nesta pasta
- **Logs**: Sempre inclua logs ao reportar problemas

---

💡 **Dica**: Comece pelo [Guia do Usuário](USER_GUIDE.md) para aprender a usar o sistema completo!

- **[PERFORMANCE.md](./PERFORMANCE.md)** - Otimizações de performance e benchmarks

### 🧪 Testes

- **[TESTING.md](./TESTING.md)** - Estratégia de testes e implementação de suites de teste

### 🎨 Design e UX

- **[DESIGN.md](./DESIGN.md)** - Guia de design e padrões visuais
- **[USER_EXPERIENCE.md](./USER_EXPERIENCE.md)** - Melhorias de experiência do usuário

### 🔧 Desenvolvimento

- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Guia para contribuidores
- **[API.md](./API.md)** - Documentação da API interna
- **[DEBUGGING.md](./DEBUGGING.md)** - Guias de debugging e troubleshooting

### 📦 Deploy e Manutenção

- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Processos de deploy e release
- **[MAINTENANCE.md](./MAINTENANCE.md)** - Guias de manutenção e monitoramento

## 🗺️ Navegação Rápida

### Para Desenvolvedores

1. Comece com [ARCHITECTURE.md](./ARCHITECTURE.md) para entender a estrutura
2. Leia [CONTRIBUTING.md](./CONTRIBUTING.md) para padrões de desenvolvimento
3. Configure testes seguindo [TESTING.md](./TESTING.md)
4. Consulte [API.md](./API.md) para APIs internas

### Para Mantenedores

1. Revise [SECURITY.md](./SECURITY.md) para aspectos de segurança
2. Implemente melhorias de [IMPROVEMENTS.md](./IMPROVEMENTS.md)
3. Use [PERFORMANCE.md](./PERFORMANCE.md) para otimizações
4. Siga [DEPLOYMENT.md](./DEPLOYMENT.md) para releases

### Para Usuários Avançados

1. Consulte [USER_EXPERIENCE.md](./USER_EXPERIENCE.md) para customizações
2. Use [DEBUGGING.md](./DEBUGGING.md) para resolução de problemas
3. Veja [DESIGN.md](./DESIGN.md) para personalização visual

## 📊 Estado da Documentação

| Documento          | Status          | Última Atualização | Prioridade |
| ------------------ | --------------- | ------------------ | ---------- |
| IMPROVEMENTS.md    | ✅ Completo     | 2025-01-24         | Alta       |
| SECURITY.md        | ✅ Completo     | 2025-01-24         | Alta       |
| ARCHITECTURE.md    | ✅ Completo     | 2025-01-24         | Alta       |
| PERFORMANCE.md     | ✅ Completo     | 2025-01-24         | Alta       |
| TESTING.md         | ✅ Completo     | 2025-01-24         | Alta       |
| DESIGN.md          | 🔄 Em Progresso | -                  | Média      |
| USER_EXPERIENCE.md | 🔄 Em Progresso | -                  | Média      |
| CONTRIBUTING.md    | 📝 Planejado    | -                  | Média      |
| API.md             | 📝 Planejado    | -                  | Baixa      |
| DEBUGGING.md       | 📝 Planejado    | -                  | Baixa      |
| DEPLOYMENT.md      | 📝 Planejado    | -                  | Baixa      |
| MAINTENANCE.md     | 📝 Planejado    | -                  | Baixa      |

## 🎯 Próximos Passos

### Fase Atual: Fundação (Completa)

- [x] Análise de melhorias
- [x] Documentação de segurança
- [x] Arquitetura proposta
- [x] Otimizações de performance
- [x] Estratégia de testes

### Próxima Fase: UX e Design

- [ ] Guia de design system
- [ ] Documentação de experiência do usuário
- [ ] Padrões de interface

### Fase Futura: Desenvolvimento

- [ ] Guia de contribuição
- [ ] Documentação de APIs
- [ ] Processos de deploy

## 🤝 Como Contribuir com a Documentação

1. **Identificar Necessidades**

   - Revise documentos existentes
   - Identifique lacunas ou informações desatualizadas
   - Propose novos tópicos

2. **Seguir Padrões**

   - Use Markdown com formato consistente
   - Inclua exemplos práticos
   - Mantenha linguagem clara e objetiva

3. **Processo de Atualização**
   - Faça fork do repositório
   - Crie branch específica para documentação
   - Submeta PR com mudanças
   - Solicite review de mantenedores

## 📧 Contato

Para dúvidas sobre a documentação ou sugestões de melhoria:

- **Issues**: Use GitHub Issues com label `documentation`
- **Discussions**: Use GitHub Discussions para perguntas gerais
- **PR**: Contribuições diretas via Pull Requests

## 📜 Licença

Toda a documentação está sob a mesma licença MIT do projeto.

---

_Esta documentação é um documento vivo e será atualizada continuamente conforme o projeto evolui._
