cmake_minimum_required(VERSION 3.20)
project(capacito VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Build type default
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# Compiler warnings
add_compile_options(-Wall -Wextra -Wpedantic -Wno-unused-parameter)

# Per-config optimization flags
add_compile_options("$<$<CONFIG:Debug>:-g>")
add_compile_options("$<$<CONFIG:Debug>:-O0>")
add_compile_options("$<$<CONFIG:Release>:-O2>")

# Dependencies via find_package (install gRPC & protobuf system-wide or via vcpkg/conan)
find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)
find_package(GTest REQUIRED)

# Protobuf / gRPC code generation
set(PROTO_PATH "${CMAKE_SOURCE_DIR}/proto")
set(PROTO_FILE "${PROTO_PATH}/capacito.proto")
set(GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
file(MAKE_DIRECTORY ${GENERATED_DIR})

get_target_property(GRPC_CPP_PLUGIN gRPC::grpc_cpp_plugin LOCATION)

add_custom_command(
  OUTPUT
    "${GENERATED_DIR}/capacito.pb.cc"
    "${GENERATED_DIR}/capacito.pb.h"
    "${GENERATED_DIR}/capacito.grpc.pb.cc"
    "${GENERATED_DIR}/capacito.grpc.pb.h"
  COMMAND protobuf::protoc
    --proto_path=${PROTO_PATH}
    --cpp_out=${GENERATED_DIR}
    --grpc_out=${GENERATED_DIR}
    --plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN}
    ${PROTO_FILE}
  DEPENDS ${PROTO_FILE}
  COMMENT "Generating protobuf and gRPC C++ sources"
)

add_library(capacito_proto
  "${GENERATED_DIR}/capacito.pb.cc"
  "${GENERATED_DIR}/capacito.grpc.pb.cc"
)
target_include_directories(capacito_proto PUBLIC ${GENERATED_DIR})
target_link_libraries(capacito_proto
  PUBLIC
    protobuf::libprotobuf
    gRPC::grpc++
)

# Main service library
add_subdirectory(src)

# Tests
enable_testing()
add_subdirectory(tests)
