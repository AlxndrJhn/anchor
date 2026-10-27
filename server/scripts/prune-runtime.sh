#!/bin/sh
# Deletes what the server's production packages ship but never load, to keep
# the Docker image small. Run in the server folder after `pnpm prune --prod`.
set -eu
cd node_modules/.pnpm

# ONNX Runtime (picture search): Node loads ort.node.min.* and the one
# WebAssembly build it imports; the rest are browser and WebGPU builds.
for dist in onnxruntime-web@*/node_modules/onnxruntime-web/dist; do
  find "$dist" -type f \
    ! -name 'ort.node.min.js' ! -name 'ort.node.min.mjs' \
    ! -name 'ort-wasm-simd-threaded.mjs' ! -name 'ort-wasm-simd-threaded.wasm' \
    -delete
done

# Tesseract (picture text): Node loads each build from its .js and .wasm;
# the .wasm.js copies, with the build inlined, are for browsers.
for core in tesseract.js-core@*/node_modules/tesseract.js-core; do
  find "$core" -type f -name 'tesseract-core*.wasm.js' -delete
done

# Prisma: the client's query compilers for databases other than Postgres.
for runtime in @prisma+client@*/node_modules/@prisma/client/runtime; do
  find "$runtime" -type f \
    \( -name '*sqlserver*' -o -name '*sqlite*' -o -name '*mysql*' -o -name '*cockroach*' \) \
    -delete
done
