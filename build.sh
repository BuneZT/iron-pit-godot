#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"

TARGET_LINUX=false
TARGET_WINDOWS=false
DEBUG_BUILD=false
RUN_TESTS=false
INSTALL_TEMPLATES=false

usage() {
    cat <<'EOF'
Usage: ./build.sh [OPTIONS]

Build standalone executables of Iron Pit on Linux / Bazzite.

Options:
  --linux               Build native Linux x86_64 executable (default)
  --windows             Cross-compile Windows x86_64 executable
  --all                 Build both Linux and Windows executables
  --debug               Build debug export instead of release
  --test, --run-tests   Run headless test suite before exporting
  --install-templates   Download and install Godot export templates
  -h, --help            Show this help message

Environment:
  GODOT_BIN             Optional explicit path to the Godot executable
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --linux)
            TARGET_LINUX=true
            shift
            ;;
        --windows)
            TARGET_WINDOWS=true
            shift
            ;;
        --all)
            TARGET_LINUX=true
            TARGET_WINDOWS=true
            shift
            ;;
        --debug)
            DEBUG_BUILD=true
            shift
            ;;
        --test|--run-tests)
            RUN_TESTS=true
            shift
            ;;
        --install-templates)
            INSTALL_TEMPLATES=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Default to Linux build when no platform flag is given
if ! $TARGET_LINUX && ! $TARGET_WINDOWS && ! $INSTALL_TEMPLATES; then
    TARGET_LINUX=true
fi

# Locate Godot binary (native or Flatpak on Bazzite)
GODOT_CMD=()
USING_FLATPAK=false

if [[ -n "${GODOT_BIN:-}" ]]; then
    if [[ ! -x "$GODOT_BIN" ]]; then
        echo "[ERROR] GODOT_BIN is set but not executable: $GODOT_BIN" >&2
        exit 1
    fi
    GODOT_CMD=("$GODOT_BIN")
elif command -v godot >/dev/null 2>&1; then
    GODOT_CMD=("$(command -v godot)")
elif compgen -G "$PROJECT_ROOT/../godot/Godot_v*_linux.x86_64" >/dev/null 2>&1; then
    LOCAL_GODOT="$(ls -1v "$PROJECT_ROOT"/../godot/Godot_v*_linux.x86_64 | tail -n 1)"
    GODOT_CMD=("$LOCAL_GODOT")
elif command -v flatpak >/dev/null 2>&1 && flatpak info org.godotengine.Godot >/dev/null 2>&1; then
    GODOT_CMD=(flatpak run org.godotengine.Godot)
    USING_FLATPAK=true
else
    echo "[ERROR] Godot executable not found." >&2
    echo "        Install Godot 4.7.2+, add it to PATH, or set GODOT_BIN=/path/to/godot." >&2
    exit 1
fi

RAW_VERSION="$("${GODOT_CMD[@]}" --version | head -n 1 | tr -d '\r')"
# Example: 4.7.2.stable.official.ed1daf0bf -> TEMPLATE_VER=4.7.2.stable, RELEASE_TAG=4.7.2-stable
VERSION_NUM="$(echo "$RAW_VERSION" | cut -d'.' -f1-3)"
VERSION_STATUS="$(echo "$RAW_VERSION" | cut -d'.' -f4)"
TEMPLATE_VER="${VERSION_NUM}.${VERSION_STATUS}"
RELEASE_TAG="${VERSION_NUM}-${VERSION_STATUS}"

if $USING_FLATPAK; then
    TEMPLATE_DIR="$HOME/.var/app/org.godotengine.Godot/data/godot/export_templates/$TEMPLATE_VER"
else
    TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATE_VER"
fi

install_export_templates() {
    local tpz_url="https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_export_templates.tpz"
    local tmp_tpz
    tmp_tpz="$(mktemp --suffix=.tpz)"
    trap 'rm -f "$tmp_tpz"' RETURN

    echo "Downloading Godot ${RELEASE_TAG} export templates..."
    echo "  URL: $tpz_url"
    curl -fL --progress-bar -o "$tmp_tpz" "$tpz_url"

    mkdir -p "$TEMPLATE_DIR"
    echo "Extracting export templates to: $TEMPLATE_DIR"
    unzip -oq -j "$tmp_tpz" "templates/*" -d "$TEMPLATE_DIR"
    echo "[SUCCESS] Export templates installed for Godot ${TEMPLATE_VER}."
}

ensure_template() {
    local template_file="$1"
    if [[ ! -f "$TEMPLATE_DIR/$template_file" ]]; then
        echo "[INFO] Export template '$template_file' not found in $TEMPLATE_DIR."
        install_export_templates
    fi
}

if $INSTALL_TEMPLATES; then
    install_export_templates
    if ! $TARGET_LINUX && ! $TARGET_WINDOWS; then
        exit 0
    fi
fi

# Ensure project resources & global class cache are imported on fresh clones
if [[ ! -d "$PROJECT_ROOT/.godot" ]]; then
    echo "Importing project assets..."
    "${GODOT_CMD[@]}" --headless --import --path "$PROJECT_ROOT"
fi

if $RUN_TESTS; then
    echo "=============================================="
    echo "Running Headless Test Suite"
    echo "=============================================="
    "${GODOT_CMD[@]}" --headless --path "$PROJECT_ROOT" -s res://tests/run_tests.gd
fi

if $DEBUG_BUILD; then
    EXPORT_FLAG="--export-debug"
    MODE_LABEL="Debug"
    TEMPLATE_FLAVOR="debug"
else
    EXPORT_FLAG="--export-release"
    MODE_LABEL="Release"
    TEMPLATE_FLAVOR="release"
fi

mkdir -p "$BUILD_DIR"

if $TARGET_LINUX; then
    ensure_template "linux_${TEMPLATE_FLAVOR}.x86_64"
    echo "=============================================="
    echo "Building Iron Pit (Linux x86_64 ${MODE_LABEL})"
    echo "=============================================="
    "${GODOT_CMD[@]}" --headless --path "$PROJECT_ROOT" "$EXPORT_FLAG" "Linux" "$BUILD_DIR/IronPit.x86_64"
    chmod +x "$BUILD_DIR/IronPit.x86_64"
    echo "[SUCCESS] Linux standalone build ready at: $BUILD_DIR/IronPit.x86_64"
fi

if $TARGET_WINDOWS; then
    ensure_template "windows_${TEMPLATE_FLAVOR}_x86_64.exe"
    echo "=============================================="
    echo "Building Iron Pit (Windows x86_64 ${MODE_LABEL})"
    echo "=============================================="
    "${GODOT_CMD[@]}" --headless --path "$PROJECT_ROOT" "$EXPORT_FLAG" "Windows Desktop" "$BUILD_DIR/IronPit.exe"
    echo "[SUCCESS] Windows standalone build ready at: $BUILD_DIR/IronPit.exe"
fi
