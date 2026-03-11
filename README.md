# capacito

A gRPC service implemented in C++20.

## Quick Start

```bash
# Build
./scripts/build.sh

# Run tests
./scripts/test.sh

# Start the server
./build/src/capacito_server
```

## Development

See [AGENTS.md](AGENTS.md) for full conventions on gRPC patterns, code style, and testing.

## Service Definition

The API is defined in [`proto/capacito.proto`](proto/capacito.proto). This is the single source of truth — edit it to add new RPCs and messages.

After editing the proto, re-build to regenerate C++ bindings:

```bash
cmake --build build
```

## Dependencies

- gRPC + Protobuf (`libgrpc++-dev`, `libprotobuf-dev`, `protobuf-compiler-grpc`)
- GoogleTest (`libgtest-dev`)
- CMake ≥ 3.20
- C++20-capable compiler (GCC 12+ or Clang 15+)
