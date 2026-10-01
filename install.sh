#!/usr/bin/env bash
#
# install.sh: instala, atualiza ou remove o plasmoid "GitHub Issues" no KDE Plasma 6.
#
# Objetivo: um comando so para instalar o widget, sem precisar clonar o repo.
# Dependencias: bash, curl e kpackagetool6 (vem com o Plasma). Nao usa jq nem unzip.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/egionCode/plasma-github-issues/master/install.sh | bash
#   ./install.sh [--version vX.Y.Z] [--local] [--uninstall] [--help]
#
# Decisoes nao obvias:
#   - Sem argumentos baixa a release mais recente (arquivo .plasmoid). Rodado de dentro
#     de um clone, usa o codigo local (util para desenvolver). Quando vem por pipe
#     (curl | bash) nunca assume que esta num clone, mesmo que o cwd seja um.
#   - Instala em ~/.local/share/plasma/plasmoids (por usuario): nao precisa de root.
#   - Valida que o download e um zip antes de instalar, para nao entregar uma pagina de
#     erro HTML ao kpackagetool6.
#   - PACKAGE_ROOT (variavel de ambiente) muda o destino da instalacao. Existe para os
#     testes automatizados nao tocarem na instalacao real do usuario.

set -euo pipefail

REPO="egionCode/plasma-github-issues"
PLUGIN_ID="com.egion.githubissues"
DEFAULT_ROOT="${HOME}/.local/share/plasma/plasmoids"

VERSION="latest"
MODE="install"
FORCE_LOCAL=0

# Cores so quando a saida e um terminal (evita lixo de escape em logs e pipes)
if [[ -t 1 ]]; then
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
    GREEN=""; YELLOW=""; RED=""; BOLD=""; RESET=""
fi
info() { printf '%s==>%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%saviso:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%serro:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
${BOLD}GitHub Issues para KDE Plasma 6${RESET}

Uso: install.sh [opcoes]

  (sem opcoes)         instala ou atualiza para a release mais recente
  --version vX.Y.Z     instala uma release especifica
  --local              usa o codigo deste clone em vez de baixar uma release
  --uninstall          remove o widget
  -h, --help           mostra esta ajuda

Instalacao em um comando:
  curl -fsSL https://raw.githubusercontent.com/${REPO}/master/install.sh | bash
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] || die "--version precisa de um valor (ex: --version v0.1.0)"
            VERSION="$2"; shift 2 ;;
        --local)     FORCE_LOCAL=1; shift ;;
        --uninstall) MODE="uninstall"; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           usage >&2; die "opcao desconhecida: $1" ;;
    esac
done

# kpackagetool6 com o destino opcional de PACKAGE_ROOT (usado nos testes)
kpt() {
    if [[ -n "${PACKAGE_ROOT:-}" ]]; then
        kpackagetool6 -t Plasma/Applet --packageroot "$PACKAGE_ROOT" "$@"
    else
        kpackagetool6 -t Plasma/Applet "$@"
    fi
}

is_installed() {
    [[ -d "${PACKAGE_ROOT:-$DEFAULT_ROOT}/${PLUGIN_ID}" ]]
}

check_requirements() {
    command -v kpackagetool6 >/dev/null 2>&1 \
        || die "kpackagetool6 nao encontrado. Este widget exige o KDE Plasma 6."
    # Plasma 5 tem outro formato de pacote: avisa em vez de falhar de forma obscura
    if command -v plasmashell >/dev/null 2>&1; then
        local major
        major="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -n1 || true)"
        if [[ -n "$major" && "$major" -lt 6 ]]; then
            die "Plasma ${major} detectado. Este widget exige o Plasma 6."
        fi
    fi
}

uninstall() {
    if ! is_installed; then
        info "O widget nao esta instalado. Nada a fazer."
        return 0
    fi
    kpt -r "$PLUGIN_ID"
    info "Widget removido."
}

# Resolve de onde instalar: clone local ou release baixada. Escreve o caminho em $SOURCE.
SOURCE=""
TMPDIR_CREATED=""
cleanup() { [[ -n "$TMPDIR_CREATED" ]] && rm -rf "$TMPDIR_CREATED"; return 0; }
trap cleanup EXIT

resolve_source() {
    # BASH_SOURCE[0] vazio = veio por pipe; nesse caso nao ha "clone ao lado do script"
    local script="${BASH_SOURCE[0]:-}"
    if [[ -n "$script" && -f "$script" ]]; then
        local dir
        dir="$(cd "$(dirname "$script")" && pwd)"
        if [[ -f "$dir/$PLUGIN_ID/metadata.json" ]] && { [[ $FORCE_LOCAL -eq 1 ]] || [[ "$VERSION" == "latest" ]]; }; then
            SOURCE="$dir/$PLUGIN_ID"
            info "Usando o codigo local: $SOURCE"
            return 0
        fi
    fi
    [[ $FORCE_LOCAL -eq 0 ]] || die "--local so funciona rodando o install.sh de dentro de um clone do repositorio."

    command -v curl >/dev/null 2>&1 || die "curl nao encontrado."
    local api="https://api.github.com/repos/${REPO}/releases/latest"
    [[ "$VERSION" == "latest" ]] || api="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"

    info "Buscando a release (${VERSION})..."
    local json url
    json="$(curl -fsSL "$api")" || die "nao consegui consultar a release '${VERSION}' (sem rede ou versao inexistente)."
    # Extrai a URL do .plasmoid sem jq
    url="$(printf '%s' "$json" | grep -oE '"browser_download_url": *"[^"]+\.plasmoid"' | head -n1 | sed -E 's/.*"(https[^"]+)"$/\1/')"
    [[ -n "$url" ]] || die "a release '${VERSION}' nao tem arquivo .plasmoid anexado."
    # Defesa: so baixa do proprio repositorio, mesmo que a resposta da API venha estranha
    [[ "$url" == "https://github.com/${REPO}/"* ]] || die "URL inesperada na release: $url"

    TMPDIR_CREATED="$(mktemp -d)"
    SOURCE="$TMPDIR_CREATED/github-issues.plasmoid"
    info "Baixando $(basename "$url")..."
    curl -fsSL -o "$SOURCE" "$url" || die "falha no download de $url"
    # Magic number de zip ("PK"): barra pagina de erro HTML ou arquivo truncado
    [[ "$(head -c2 "$SOURCE")" == "PK" ]] || die "o arquivo baixado nao e um pacote valido."
}

post_install_hints() {
    echo
    info "Pronto. Para usar: clique direito no desktop ou painel, \"Adicionar widgets\", \"GitHub Issues\"."
    if ! command -v gh >/dev/null 2>&1; then
        warn "GitHub CLI (gh) nao encontrado. O widget usa o token do gh: instale-o e rode 'gh auth login'."
    elif ! gh auth status >/dev/null 2>&1; then
        warn "O gh nao esta autenticado. Rode 'gh auth login' para o widget conseguir listar suas issues."
    fi
    echo "Se o widget nao aparecer na lista, reinicie o shell: kquitapp6 plasmashell && kstart plasmashell"
}

main() {
    check_requirements
    if [[ "$MODE" == "uninstall" ]]; then
        uninstall
        return 0
    fi
    resolve_source
    if is_installed; then
        info "Atualizando a instalacao existente..."
        kpt -u "$SOURCE"
    else
        info "Instalando..."
        kpt -i "$SOURCE"
    fi
    post_install_hints
}

main
