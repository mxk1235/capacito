# TODO: Switch from INTERFACE to a real library once you have source files:
#   add_library(capacito_lib
#     capacito_service_impl.cc
#   )
add_library(capacito_lib INTERFACE)

target_include_directories(capacito_lib
  INTERFACE
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(capacito_lib
  INTERFACE
    capacito_proto
)

# Server executable
add_executable(capacito_server
  main.cc
)

target_link_libraries(capacito_server
  PRIVATE
    capacito_lib
    gRPC::grpc++_reflection
)
