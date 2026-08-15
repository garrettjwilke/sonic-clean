#!/bin/bash

set -e

rm -f S3CE.gen S3CE.p S3CE.h S3CE.log

echo "Using:"
/opt/asl/asl -h 2>&1 | head -5 || true

echo
echo "Assembling S.C.E..."

/opt/asl/asl @Tools/AS/Linux/asflags Engine/Includes.asm

test -f S3CE.log && cat S3CE.log || true

if [ ! -f S3CE.p ]; then
    echo "Assembler did not produce S3CE.p"
    exit 1
fi

echo "Assembly succeeded."

# Use S.C.E.'s own tools for the remaining steps.
#/opt/asl/p2bin -p=FF -z=0,kosinskiplus,Size_of_Snd_driver_guess,after \
Tools/AS/Linux/p2bin -p=FF -z=0,kosinskiplus,Size_of_Snd_driver_guess,after \
    S3CE.p S3CE.gen S3CE.h

rm -f S3CE.p S3CE.h

Tools/AS/Linux/convsym S3CE.lst S3CE.gen \
    -input as_lst \
    -range 0 FFFFFF \
    -exclude \
    -filter "z[A-Z].+" \
    -a

Tools/AS/Linux/convsym S3CE.lst "Engine/_RAM.lst" \
    -in as_lst \
    -out asm \
    -range FF0000 FFFFFF

Tools/AS/Linux/fixheader S3CE.gen

if [ -f S3CE.gen ]; then
    echo
    echo "SUCCESS: S3CE.gen was built."
else
    echo "ERROR: S3CE.gen was not produced."
    exit 1
fi
