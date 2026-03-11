add_executable(capacito_tests
  # TODO: Add your test source files here
  # e.g. capacito_service_test.cc
  placeholder_test.cc
)

target_link_libraries(capacito_tests
  PRIVATE
    capacito_lib
    GTest::gtest_main
    GTest::gmock
)

include(GoogleTest)
gtest_discover_tests(capacito_tests)
