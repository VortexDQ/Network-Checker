cmake_minimum_required(VERSION 3.12)
project(netrepair VERSION 3.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(netrepair src/main.cpp)

# Release build optimizations
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()
target_compile_options(netrepair PRIVATE
  $<$<CXX_COMPILER_ID:GNU,Clang>:-O2 -Wall>
  $<$<CXX_COMPILER_ID:MSVC>:/O2 /W3 /EHsc>
)

# Windows: link socket and IP helper libraries
if(WIN32)
  target_link_libraries(netrepair PRIVATE ws2_32 iphlpapi)
endif()

# Install target (optional)
install(TARGETS netrepair DESTINATION bin)
