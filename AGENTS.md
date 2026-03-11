# Agent Instructions — capacito

This document is the authoritative guide for AI agents and contributors working on the **capacito** gRPC C++ service. Read it in full before making any changes.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Layout](#repository-layout)
3. [gRPC Conventions & Patterns](#grpc-conventions--patterns)
4. [Code Style & Structure](#code-style--structure)
5. [Testing Guidelines](#testing-guidelines)
6. [Build & Tooling](#build--tooling)
7. [Common Pitfalls](#common-pitfalls)

---

## Project Overview

**capacito** is a gRPC service implemented in C++20. The service definition lives in `proto/capacito.proto` and is the single source of truth for the API surface. All implementation code must conform to the generated interface — never hand-roll gRPC plumbing.

---

## Repository Layout

```
capacito/
├── proto/                  # Protobuf/gRPC definitions (source of truth)
│   └── capacito.proto
├── src/                    # Service implementation & server entrypoint
│   ├── main.cc
│   └── CMakeLists.txt
├── include/capacito/       # Public headers (one per class)
├── tests/                  # All tests (unit + integration)
├── cmake/                  # CMake helper modules
├── scripts/                # build.sh, test.sh helpers
└── .github/workflows/      # CI configuration
```

**Rules:**
- `proto/` — only `.proto` files. Never put generated code here.
- `src/` — implementation (`.cc`) files only. Headers go in `include/capacito/`.
- `include/capacito/` — public headers. One header per class. No inline implementation unless it's a template or trivial accessor.
- `tests/` — mirrors `src/` structure. A file `src/foo.cc` should have a test `tests/foo_test.cc`.

---

## gRPC Conventions & Patterns

### Proto File Rules

- Package: always `capacito.v1` — include the version in the package name.
- Use `snake_case` for field names. Use `PascalCase` for message and service names.
- Every RPC must have its own dedicated request and response message — never reuse messages across RPCs, even if they look identical today.
- Add a comment block to every RPC describing: purpose, expected latency class (low/medium/high), and whether it is idempotent.
- Reserve field numbers when removing fields — never reuse a field number.

```protobuf
// Good
rpc GetWidget (GetWidgetRequest) returns (GetWidgetResponse);

// Bad — reusing a generic message
rpc GetWidget (GenericRequest) returns (GenericResponse);
```

### RPC Patterns

| Pattern | Use when |
|---|---|
| Unary | Simple request/response; most RPCs should start here |
| Server streaming | Large result sets or live updates pushed to client |
| Client streaming | Bulk ingestion / upload workflows |
| Bidirectional streaming | Real-time interactive sessions |

Default to **unary** unless there is an explicit reason for streaming. Streaming adds significant complexity to error handling and testing.

### Service Implementation

- Each service RPC maps to a method on a class that inherits from the generated `ServiceBase`. Keep the class thin — delegate to a separate domain object or handler.
- Return `grpc::Status` with a meaningful `StatusCode`. Never return `OK` on a logical error.
- Prefer `INVALID_ARGUMENT` for bad input, `NOT_FOUND` for missing resources, `INTERNAL` only as a last resort.
- Log every non-OK status at `WARNING` or above before returning it.

```cpp
// Good
grpc::Status CapacitoServiceImpl::GetWidget(
    grpc::ServerContext* ctx,
    const GetWidgetRequest* req,
    GetWidgetResponse* resp) {

    if (req->id().empty()) {
        return grpc::Status(grpc::StatusCode::INVALID_ARGUMENT, "id must not be empty");
    }
    // ...
    return grpc::Status::OK;
}
```

### Deadlines & Cancellation

- Always check `ctx->IsCancelled()` in streaming handlers and long-running unary RPCs before doing expensive work.
- Never block indefinitely in an RPC handler. Any I/O must respect the deadline.

### Metadata

- Use lowercase hyphenated keys for custom metadata: `x-capacito-request-id`.
- Read metadata defensively — treat any absent key as a no-op, not an error.

---

## Code Style & Structure

### General

- **Standard:** C++20. Use modern features (`std::span`, ranges, concepts) where they improve clarity — not as demonstrations of novelty.
- **Formatting:** Clang-format with Google style base. Run `clang-format -i` before every commit. The CI will reject unformatted code.
- **Naming:**
  - Types & classes: `PascalCase`
  - Functions & methods: `PascalCase` (Google C++ convention)
  - Variables & parameters: `snake_case`
  - Constants & enums: `kPascalCase`
  - Private member variables: `trailing_underscore_`

### Headers

- All headers must have `#pragma once`.
- Group includes in this order, separated by blank lines:
  1. Corresponding `.h` for a `.cc` file
  2. C++ standard library headers
  3. Third-party headers (gRPC, protobuf, etc.)
  4. Internal project headers
- Never use `using namespace` in headers.

```cpp
#pragma once

#include <memory>
#include <string>

#include <grpcpp/grpcpp.h>

#include "capacito/widget_repository.h"
```

### Classes

- One class per header/source file pair.
- Declare the public interface first, then protected, then private.
- Prefer composition over inheritance except for the generated gRPC service base classes.
- Mark all single-argument constructors `explicit`.
- Delete copy constructor and copy assignment for service implementation classes; they should not be copied.

### Error Handling

- No raw exceptions crossing gRPC boundaries — catch at the handler level and convert to `grpc::Status`.
- Use `std::expected` (C++23) or explicit result types for internal domain logic that can fail — avoid using exceptions for control flow.
- Never swallow errors silently. Every error path must either return, log, or propagate.

### Memory & Ownership

- Prefer stack allocation and value semantics. Use `std::unique_ptr` for owned heap objects, `std::shared_ptr` only when shared ownership is genuinely needed.
- Never use raw `new`/`delete`.
- Protobuf messages are value types — pass by const reference for read, by pointer for output parameters (as gRPC generates).

---

## Testing Guidelines

### Test Philosophy

- Every RPC method must have at least one unit test and one integration test.
- Unit tests cover: happy path, each distinct error path, and edge cases (empty input, maximum sizes).
- Integration tests exercise the full gRPC stack using an in-process server.

### Framework

- **Unit tests:** GoogleTest (`gtest`) + GoogleMock (`gmock`).
- **Integration tests:** Use `grpc::testing::ServerContext` and an in-process channel (`grpc::CreateChannel` with `InsecureChannelCredentials` and a local port or `inproc` transport).

### File & Naming Conventions

- Test files: `tests/<subject>_test.cc` mirroring `src/<subject>.cc`.
- Test suites: `<ClassName>Test`
- Test names: describe the scenario in plain English using `_` separators — `GetWidget_ReturnsNotFound_WhenIdMissing`.

```cpp
TEST(CapacitoServiceTest, GetWidget_ReturnsInvalidArgument_WhenIdIsEmpty) {
    // Arrange
    grpc::ServerContext ctx;
    GetWidgetRequest req;  // id intentionally left empty
    GetWidgetResponse resp;

    // Act
    auto status = service_.GetWidget(&ctx, &req, &resp);

    // Assert
    EXPECT_EQ(status.error_code(), grpc::StatusCode::INVALID_ARGUMENT);
}
```

### Mocking

- Define mock classes in a `tests/mocks/` subdirectory, not inline in test files.
- Use `MOCK_METHOD` (not the legacy `MOCK_METHOD0` etc.) for all new mocks.
- Avoid mocking types you don't own (e.g., protobuf messages) — construct real instances instead.

### What Not to Test

- Do not test the behaviour of gRPC or protobuf internals.
- Do not test generated code from `capacito.pb.cc` / `capacito.grpc.pb.cc`.
- Do not write tests that depend on wall-clock time — inject a clock abstraction.

### Coverage

- Aim for ≥ 80% line coverage on `src/`. CI will report coverage but will not block on it initially — this threshold will be enforced once the service reaches v1.0.

---

## Build & Tooling

### Prerequisites

```
cmake >= 3.20
clang or gcc with C++20 support
libgrpc++-dev
libprotobuf-dev
protobuf-compiler-grpc
libgtest-dev
```

### Quick Start

```bash
./scripts/build.sh          # configure + build (Release)
./scripts/test.sh           # run all tests
BUILD_TYPE=Debug ./scripts/build.sh   # debug build
```

### Code Generation

Protobuf and gRPC C++ sources are generated automatically during CMake configure into `build/generated/`. **Never commit generated files.** They are in `.gitignore`.

If you change `proto/capacito.proto`, re-run `cmake --build build` and the generated files will be refreshed automatically.

### Linting & Formatting

```bash
# Format all sources
find src include tests -name '*.cc' -o -name '*.h' | xargs clang-format -i

# Static analysis (if clang-tidy is available)
clang-tidy src/*.cc -- $(cat build/compile_commands.json | python3 -c "...")
```

---

## SQL Schema Generation

SQL DDL is generated automatically from annotated proto files in `proto/objects/` using `protoc` with a custom plugin. The plugin lives at `tools/protoc-gen-sql` and outputs `.sql` files into `schema/<dialect>/`. **Never hand-edit files in `schema/`** — they are regenerated and any manual changes will be overwritten.

### Supported dialects

| Dialect | Output path | Notes |
|---|---|---|
| `postgres` | `schema/postgres/<n>.sql` | Native enum types, triggers, `IF NOT EXISTS` |
| `spanner` | `schema/spanner/<n>.sql` | `STRING`/`INT64`/`BOOL`, `CHECK` for enums, table-level `PRIMARY KEY`, `ALLOW_COMMIT_TIMESTAMP` |

Run a single dialect with `./scripts/gen-schema.sh --dialect=postgres` or generate all at once with `./scripts/gen-schema.sh`.

### How it works

`protoc` fully parses the `.proto` files (resolving imports, types, and source location info) and passes a `CodeGeneratorRequest` to the plugin over stdin. The plugin builds a dialect-agnostic intermediate representation from the descriptor, then runs each dialect's emitter class against it independently. Adding a new dialect means adding a new `SqlEmitter` subclass and registering it in `_EMITTERS` — no changes to the parsing or IR code.

### Adding a new object

1. Create `proto/objects/<name>.proto` with a `message` definition.
2. Annotate the message and fields with `sql:` comments (see below).
3. Run the generator: `./scripts/gen-schema.sh`
4. Commit both the `.proto` file and the generated `.sql` file together.

CI enforces that `schema/` is always in sync with `proto/objects/` — a stale schema will fail the build.

### Annotation reference

| Annotation | Scope | Example | Effect |
|---|---|---|---|
| `sql:table=<n>` | Message | `// sql:table=projects` | Sets the SQL table name |
| `sql:primary_key=<field>` | Message | `// sql:primary_key=id` | Marks a field as PRIMARY KEY |
| `sql:type=<SQL TYPE>` | Field | `// sql:type=VARCHAR(64) NOT NULL` | Overrides inferred type for **all** dialects |
| `sql:postgres_type=<TYPE>` | Field | `// sql:postgres_type=TIMESTAMPTZ NOT NULL` | Overrides inferred type for PostgreSQL only |
| `sql:spanner_type=<TYPE>` | Field | `// sql:spanner_type=TIMESTAMP NOT NULL` | Overrides inferred type for Spanner only |
| `sql:interleave_in=<table>` | Message | `// sql:interleave_in=users` | [Spanner] `INTERLEAVE IN PARENT` |
| `sql:ignore` | Field | `// sql:ignore` | Excludes the field from all DDL |
| `sql:index` | Field | `// sql:index` | Adds a plain index |
| `sql:unique` | Field | `// sql:unique` | Adds a UNIQUE index |
| `sql:references=<table(col)>` | Field | `// sql:references=users(id)` | Adds a FOREIGN KEY constraint |

### Default proto to SQL type mappings

| Proto type | SQL type |
|---|---|
| `string` | `TEXT` |
| `int32` / `sint32` | `INTEGER` |
| `int64` / `sint64` | `BIGINT` |
| `float` | `REAL` |
| `double` | `DOUBLE PRECISION` |
| `bool` | `BOOLEAN` |
| `bytes` | `BYTEA` |
| `google.protobuf.Timestamp` | `TIMESTAMPTZ` |
| enum (any) | PostgreSQL `CREATE TYPE ... AS ENUM` |
| Nested message | `JSONB` (with a comment) |

### Automatic behaviours

- **Enums** are emitted as PostgreSQL `CREATE TYPE ... AS ENUM`. The `_UNSPECIFIED` sentinel is excluded and the `SCREAMING_SNAKE_CASE` prefix is stripped (e.g. `PROJECT_STATUS_ACTIVE` becomes `active`).
- **updated_at trigger** — if a table has an `updated_at` column, a `set_updated_at()` function and `BEFORE UPDATE` trigger are emitted automatically.

---

## Common Pitfalls

| Pitfall | What to do instead |
|---|---|
| Blocking in an async handler | Use deadlines and check `ctx->IsCancelled()` |
| Reusing proto message types across RPCs | Define dedicated request/response messages per RPC |
| Catching `grpc::Status` as exception | `grpc::Status` is a value type, not an exception |
| Writing to `ServerContext` after RPC returns | All writes must complete before returning `grpc::Status` |
| Using `shared_ptr` for service impl | The server owns the impl; use a plain member or `unique_ptr` |
| Hard-coding port 50051 outside `main.cc` | Pass address/port via config or environment variable |

---

*Keep this file up to date as the service evolves. It is read by both humans and agents.*
