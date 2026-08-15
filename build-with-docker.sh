#!/bin/bash

set -e

IMAGE_NAME="sce-builder"

echo "==> Building Docker image..."
docker build \
    --platform linux/amd64 \
    -t "$IMAGE_NAME" \
    .

echo
echo "==> Building S.C.E..."
docker run --rm \
    --platform linux/amd64 \
    -v "$PWD:/sce" \
    -w /sce \
    "$IMAGE_NAME"

echo
echo "==> Build complete!"
echo "ROM: $PWD/S3CE.gen"
