#!/usr/bin/env bash
# Sets LD_LIBRARY_PATH / DYLD_LIBRARY_PATH / PATH and DBT_ALLOW_EXPERIMENTAL_ADAPTERS
# for dbt-fusion + Exasol ADBC on Linux, macOS, and Windows (Git Bash).
#
# Must be sourced, not executed:
#   source scripts/setup_fusion_env.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced so the variables are set in your shell:"
    echo "  source ${BASH_SOURCE[0]}"
    exit 1
fi

# --- dbc must be installed ---
if ! command -v dbc &>/dev/null; then
    echo "Error: dbc not found. Install it with:"
    echo "  curl -LsSf https://dbc.columnar.tech/install.sh | sh"
    return 1
fi

# --- Detect architecture ---
case "$(uname -m)" in
    x86_64)        ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *)             ARCH="amd64" ;;
esac

# --- Detect OS and set the right variable ---
case "$(uname -s)" in
    Linux)
        DRIVER_DIR=$(ls -d "$HOME/.config/adbc/drivers/exasol_linux_${ARCH}_v"* 2>/dev/null | sort -V | tail -1)
        export LD_LIBRARY_PATH="${DRIVER_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        ENV_VAR="LD_LIBRARY_PATH"
        ;;
    Darwin)
        # dbc installs as exasol_macos_<arch>_v<ver>, not exasol_darwin_*
        DRIVER_DIR=$(ls -d "$HOME/Library/Application Support/ADBC/Drivers/exasol_macos_${ARCH}_v"* 2>/dev/null | sort -V | tail -1)
        export DYLD_LIBRARY_PATH="${DRIVER_DIR}${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}"
        ENV_VAR="DYLD_LIBRARY_PATH"

        # Hardened-runtime binaries (e.g. dbt-fusion) silently strip DYLD_LIBRARY_PATH.
        # Symlinking the driver into /opt/homebrew/lib/ is the only reliable path on macOS.
        DYLIB="${DRIVER_DIR}/libadbc_driver_exasol.dylib"
        HOMEBREW_LIB="/opt/homebrew/lib"
        if [[ -f "$DYLIB" && -d "$HOMEBREW_LIB" ]]; then
            ln -sf "$DYLIB" "${HOMEBREW_LIB}/libadbc_driver_exasol.dylib"
            echo "OK  symlink -> ${HOMEBREW_LIB}/libadbc_driver_exasol.dylib"
        fi
        unset DYLIB HOMEBREW_LIB
        ;;
    MINGW*|MSYS*|CYGWIN*)
        DRIVER_DIR=$(ls -d "${LOCALAPPDATA//\\//}/ADBC/drivers/exasol_windows_${ARCH}_v"* 2>/dev/null | sort -V | tail -1)
        export PATH="${DRIVER_DIR}:${PATH}"
        ENV_VAR="PATH"
        ;;
    *)
        echo "Error: unsupported OS '$(uname -s)'"
        return 1
        ;;
esac

# --- Warn if the directory doesn't exist ---
if [[ ! -d "$DRIVER_DIR" ]]; then
    echo "Warning: driver directory not found: $DRIVER_DIR"
    echo "Re-run: dbc install exasol"
    return 1
fi

export DBT_ALLOW_EXPERIMENTAL_ADAPTERS=1

echo "OK  $ENV_VAR -> $DRIVER_DIR"
echo "OK  DBT_ALLOW_EXPERIMENTAL_ADAPTERS=1"

unset ARCH DRIVER_DIR ENV_VAR
