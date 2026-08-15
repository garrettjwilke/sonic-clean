#!/bin/bash
set -e

# Change to the repository root directory
cd "$(dirname "$0")"

# Delete intermediate assembler output
rm -f S3CE.gen
rm -f S3CE.p
rm -f S3CE.h
rm -f S3CE.log

# Detect Operating System and select tools directory
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Darwin)
        DEFAULT_TOOLS_DIR="Tools/AS/macOS"
        ;;
    Linux)
        DEFAULT_TOOLS_DIR="Tools/AS/Linux"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        DEFAULT_TOOLS_DIR="Tools/AS/Windows"
        ;;
    *)
        DEFAULT_TOOLS_DIR="Tools/AS/$OS_TYPE"
        ;;
esac

AS_MSGPATH="${AS_MSGPATH:-$DEFAULT_TOOLS_DIR}"
export AS_MSGPATH
export USEANSI=n

if [ ! -d "$AS_MSGPATH" ]; then
    echo "Error: Tools directory '$AS_MSGPATH' not found."
    echo "Please run './build-tools.sh' first to build the assembler tools for your system."
    exit 1
fi

# Locate assembler binary (asl, asl.exe, or asw.exe)
if [ -x "${AS_MSGPATH}/asl" ]; then
    ASL_BIN="${AS_MSGPATH}/asl"
elif [ -x "${AS_MSGPATH}/asl.exe" ]; then
    ASL_BIN="${AS_MSGPATH}/asl.exe"
elif [ -x "${AS_MSGPATH}/asw.exe" ]; then
    ASL_BIN="${AS_MSGPATH}/asw.exe"
else
    echo "Error: AS assembler not found in '$AS_MSGPATH'."
    echo "Please run './build-tools.sh' first."
    exit 1
fi

# Locate p2bin
if [ -x "${AS_MSGPATH}/p2bin" ]; then
    P2BIN_BIN="${AS_MSGPATH}/p2bin"
elif [ -x "${AS_MSGPATH}/p2bin.exe" ]; then
    P2BIN_BIN="${AS_MSGPATH}/p2bin.exe"
else
    echo "Error: p2bin not found in '$AS_MSGPATH'."
    echo "Please run './build-tools.sh' first."
    exit 1
fi

# Locate convsym
if [ -x "${AS_MSGPATH}/convsym" ]; then
    CONVSYM_BIN="${AS_MSGPATH}/convsym"
elif [ -x "${AS_MSGPATH}/convsym.exe" ]; then
    CONVSYM_BIN="${AS_MSGPATH}/convsym.exe"
else
    echo "Error: convsym not found in '$AS_MSGPATH'."
    echo "Please run './build-tools.sh' first."
    exit 1
fi

# Locate header fixer (romfix or fixheader)
if [ -x "${AS_MSGPATH}/romfix" ]; then
    FIXER_BIN="${AS_MSGPATH}/romfix"
elif [ -x "${AS_MSGPATH}/romfix.exe" ]; then
    FIXER_BIN="${AS_MSGPATH}/romfix.exe"
elif [ -x "${AS_MSGPATH}/fixheader" ]; then
    FIXER_BIN="${AS_MSGPATH}/fixheader"
elif [ -x "${AS_MSGPATH}/fixheader.exe" ]; then
    FIXER_BIN="${AS_MSGPATH}/fixheader.exe"
else
    FIXER_BIN=""
fi

# Locate asflags
if [ -f "${AS_MSGPATH}/asflags" ]; then
    ASFLAGS="${AS_MSGPATH}/asflags"
elif [ -f "Tools/AS/macOS/asflags" ]; then
    ASFLAGS="Tools/AS/macOS/asflags"
elif [ -f "Tools/AS/Linux/asflags" ]; then
    ASFLAGS="Tools/AS/Linux/asflags"
else
    ASFLAGS="Tools/AS/Windows/asflags"
fi

# Run the assembler
"$ASL_BIN" "@${ASFLAGS}" "$@" Engine/Includes.asm

test -f S3CE.log && cat S3CE.log
if [ ! -f S3CE.p ]; then
    echo "Assembler did not produce S3CE.p"
    exit 1
fi

# Convert the assembled file to binary
"$P2BIN_BIN" -p=FF -z=0,kosinskiplus,Size_of_Snd_driver_guess,after S3CE.p S3CE.gen S3CE.h

# Delete temporary files
rm -f S3CE.p
rm -f S3CE.h

# Generate debug information
"$CONVSYM_BIN" S3CE.lst S3CE.gen -input as_lst -range 0 FFFFFF -exclude -filter "z[A-Z].+" -a
"$CONVSYM_BIN" S3CE.lst "Engine/_RAM.lst" -in as_lst -out asm -range FF0000 FFFFFF

# Fix ROM header and checksum
if [ -n "$FIXER_BIN" ]; then
    "$FIXER_BIN" S3CE.gen
fi

if test -f S3CE.gen; then
    echo "Build succeeded: S3CE.gen created successfully."
    exit 0
fi

exit 1
