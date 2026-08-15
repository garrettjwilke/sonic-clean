#!/bin/bash
set -e

# Change to repo root directory
cd "$(dirname "$0")"

echo "=================================================="
echo " Building Mega Drive Assembler Tools from Source  "
echo "=================================================="

# Detect OS
OS_TYPE="$(uname -s)"
ARCH_TYPE="$(uname -m)"
EXE_EXT=""

case "$OS_TYPE" in
    Darwin)
        DEFAULT_DEST="Tools/AS/macOS"
        ;;
    Linux)
        DEFAULT_DEST="Tools/AS/Linux"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        DEFAULT_DEST="Tools/AS/Windows"
        EXE_EXT=".exe"
        ;;
    *)
        DEFAULT_DEST="Tools/AS/$OS_TYPE"
        ;;
esac

# Allow overriding destination directory via argument
DEST_DIR="${1:-$DEFAULT_DEST}"
echo "Detected OS:       $OS_TYPE ($ARCH_TYPE)"
echo "Target Directory:  $DEST_DIR"
echo ""

# Number of parallel jobs
if command -v nproc >/dev/null 2>&1; then
    JOBS=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
    JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
else
    JOBS=4
fi

# 1. Initialize submodules
echo "[1/5] Initializing / Updating Git Submodules..."
git submodule update --init --recursive

# 2. Build Macro Assembler AS (asl) and message catalogs
echo ""
echo "[2/5] Building Macro Assembler AS (asl)..."
AS_DIR="Tools/AS/asl-releases"

# Create a clean portable Makefile.def for AS
cat << 'EOF' > "${AS_DIR}/Makefile.def"
OBJDIR =
CC ?= gcc
CFLAGS = -O3 -fomit-frame-pointer -Wall
HOST_OBJEXTENSION = .o
LD = $(CC)
LDFLAGS =
HOST_EXEXTENSION =

TARG_OBJDIR = $(OBJDIR)
TARG_CC = $(CC)
TARG_CFLAGS = $(CFLAGS)
TARG_OBJEXTENSION = $(HOST_OBJEXTENSION)
TARG_LD = $(LD)
TARG_LDFLAGS = $(LDFLAGS)
TARG_EXEXTENSION = $(HOST_EXEXTENSION)

BINDIR = /usr/local/bin
INCDIR = /usr/local/include/asl
MANDIR = /usr/local/share/man
LIBDIR = /usr/local/lib/asl
DOCDIR = /usr/local/share/doc/asl
EOF

make -C "${AS_DIR}" clean >/dev/null 2>&1 || true
make -C "${AS_DIR}" -j"${JOBS}" binaries

# 3. Build p2bin (Clownacy version with Kosinski / Kosinski+ support)
echo ""
echo "[3/5] Building p2bin..."
P2BIN_DIR="Tools/AS/p2bin"
if [ ! -d "${P2BIN_DIR}" ]; then
    echo "Cloning p2bin repository..."
    git clone --recurse-submodules https://github.com/Clownacy/p2bin.git "${P2BIN_DIR}"
fi

cmake -B "${P2BIN_DIR}/build" -S "${P2BIN_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${P2BIN_DIR}/build" --config Release -j"${JOBS}"

# 4. Build convsym (Symbol table converter)
echo ""
echo "[4/5] Building convsym..."
CONVSYM_DIR="Tools/AS/md-modules/utils/convsym"
make -C "${CONVSYM_DIR}" clean >/dev/null 2>&1 || true
make -C "${CONVSYM_DIR}"

# 5. Build romfix (ROM header checksum & padding utility)
echo ""
echo "[5/5] Building romfix..."
ROMFIX_DIR="Tools/AS/mdtools/romfix"
make -C "${ROMFIX_DIR}" clean >/dev/null 2>&1 || true
make -C "${ROMFIX_DIR}"

# 6. Install all built tools into destination directory
echo ""
echo "Installing tools to ${DEST_DIR}..."
mkdir -p "${DEST_DIR}"

# Copy asl and message catalogs
cp "${AS_DIR}/asl${EXE_EXT}" "${DEST_DIR}/"
cp "${AS_DIR}"/*.msg "${DEST_DIR}/"

# Copy p2bin
if [ -f "${P2BIN_DIR}/build/p2bin${EXE_EXT}" ]; then
    cp "${P2BIN_DIR}/build/p2bin${EXE_EXT}" "${DEST_DIR}/"
elif [ -f "${P2BIN_DIR}/build/Release/p2bin${EXE_EXT}" ]; then
    cp "${P2BIN_DIR}/build/Release/p2bin${EXE_EXT}" "${DEST_DIR}/"
fi

# Copy convsym
if [ -f "Tools/AS/md-modules/build/utils/convsym${EXE_EXT}" ]; then
    cp "Tools/AS/md-modules/build/utils/convsym${EXE_EXT}" "${DEST_DIR}/"
elif [ -f "${CONVSYM_DIR}/convsym${EXE_EXT}" ]; then
    cp "${CONVSYM_DIR}/convsym${EXE_EXT}" "${DEST_DIR}/"
fi

# Copy romfix
cp "${ROMFIX_DIR}/romfix${EXE_EXT}" "${DEST_DIR}/"

# Ensure asflags and asflags_debug exist in destination directory
if [ ! -f "${DEST_DIR}/asflags" ]; then
    if [ -f "Tools/AS/Linux/asflags" ]; then
        cp "Tools/AS/Linux/asflags" "${DEST_DIR}/"
    else
        cat << 'EOF' > "${DEST_DIR}/asflags"
-cpu 68000
-xx
-n
-q
-c
-A
-L
-OLIST S3CE.lst
-o S3CE.p
-shareout S3CE.h
-U
-E S3CE.log
-i .
EOF
    fi
fi

if [ ! -f "${DEST_DIR}/asflags_debug" ]; then
    if [ -f "Tools/AS/Linux/asflags_debug" ]; then
        cp "Tools/AS/Linux/asflags_debug" "${DEST_DIR}/"
    else
        cat << 'EOF' > "${DEST_DIR}/asflags_debug"
-cpu 68000
-xx
-n
-q
-c
-D __DEBUG__
-A
-L
-OLIST S3CE.debug.lst
-o S3CE.debug.p
-shareout S3CE.debug.h
-U
-E S3CE.debug.log
-i .
EOF
    fi
fi

# Ensure execute permissions on binary tools
chmod +x "${DEST_DIR}"/asl* "${DEST_DIR}"/p2bin* "${DEST_DIR}"/convsym* "${DEST_DIR}"/romfix* 2>/dev/null || true

echo ""
echo "=================================================="
echo " Build & Installation Complete!                   "
echo " Destination: ${DEST_DIR}                         "
echo " Installed files:                                 "
ls -la "${DEST_DIR}"
echo "=================================================="
