# Changelog — Personalizações KDE

Histórico de modificações personalizadas realizadas no KDE Plasma (CachyOS, Wayland).

---

## Ícones da Bandeja (System Tray)

**Problema:** Ícones de Steam, qBittorrent, Discord e ZapZap na bandeja do sistema estavam coloridos (hardcoded) e não seguiam o esquema de cores monochrome do tema.

**Diagnóstico:**
- KDE Plasma 6.7.4 com ícones `breeze-dark`, esquema de cores `DarkPastels`, tema visual `polar-gleam`
- Os 4 apps entregam seus próprios ícones coloridos via DBus (StatusNotifierItem), ignorando o tema de ícones
- O Plasma não consegue tingir ícones embutidos pelos apps

**Solução implementada:**
1. Instalação do widget **Plasma Panel Colorizer** (`luisbocanegra.panel.colorizer` v8.0.0) via `kpackagetool6` (usuário local, sem sudo)
   - O recurso "System Tray Icons Replacer" substitui ícones coloridos por versões monocromáticas
   - As regras internas já cobrem Discord e qBittorrent; ZapZap precisa de regra manual
   - Steam usa ícone do tema de ícones (não-hardcoded no Papirus)
2. Criação de ícones SVG monocromáticos personalizados para qBittorrent e ZapZap:
   - `qbittorrent.svg`
   - `zapzap.svg`
   (Discord já possui regra interna no Panel Colorizer; Steam já tem ícone não-hardcoded no Papirus Colors Dark)
3. Geração dos arquivos de configuração:
   - `trayIconReplacements.json` — regras de substituição por regex do título do app
   - `trayIconReplacements-sha1.json` — regras de substituição por hash SHA1 do ícone

**Nota:** O recurso completo de substituição de ícones da bandeja requer o plugin C++ (`org.kde.plasma.panelcolorizer`), que precisa ser compilado e instalado via AUR com sudo:
```bash
paru -S --needed plasma6-applets-panel-colorizer
```
Após a instalação, reinicie o Plasma com `kquitapp6 plasmashell && kstart6 plasmashell`.

---

## Decoração de Janela Gruvbox (Aurorae)

**Tarefa:** Criar uma decoração de janela com as cores do tema Gruvbox escuro, copiando o tema Nordic.

**Arquivos criados:**
- `~/.local/share/aurorae/themes/Gruvbox/` — tema Aurorae completo
  - Todos os SVGs do Nordic recoloridos para a paleta Gruvbox Dark
  - `metadata.desktop` com nome do tema atualizado
  - `Gruvboxrc` com cores do título mapeadas para Gruvbox

**Mapeamento de cores Nord → Gruvbox:**

| Nord | Gruvbox | Uso |
|------|---------|-----|
| `#232831` | `#282828` | Fundo da janela |
| `#3b4252` | `#3c3836` | Fundo secundário |
| `#bf616a` | `#fb4934` | Botão fechar (vermelho) |
| `#a3be8c` | `#b8bb26` | Botão maximizar (verde) |
| `#ebcb8b` | `#fabd2f` | Botão minimizar (amarelo) |
| `#b48ead` | `#d3869b` | Botão sempre visível (roxo) |
| `#d08770` | `#fe8019` | Botão sempre abaixo (laranja) |
| `#ffffff` | `#fbf1c7` | Texto/destaque |