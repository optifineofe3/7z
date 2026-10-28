cmake_minimum_required(VERSION 3.15)
project(7ZipCore LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 99)

# Read source files from sources_7zip.txt
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/sources_7zip.txt" RAW_SOURCES)

set(SOURCES_LIST "")
foreach(SRC_LINE ${RAW_SOURCES})
    string(STRIP "${SRC_LINE}" SRC_TRIM)
    if(NOT "${SRC_TRIM}" MATCHES "^#" AND NOT "${SRC_TRIM}" STREQUAL "")
        list(APPEND SOURCES_LIST "${CMAKE_CURRENT_SOURCE_DIR}/../${SRC_TRIM}")
    endif()
endforeach()

list(APPEND SOURCES_LIST "${CMAKE_CURRENT_SOURCE_DIR}/sz_wrapper.cpp")

add_library(7ZipCore STATIC ${SOURCES_LIST})

target_include_directories(7ZipCore PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/Common"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/Windows"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/7zip"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/7zip/Common"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/C"
)

target_compile_definitions(7ZipCore PRIVATE
    Z7_PROG_VARIANT_Z=1
    _REENTRANT=1
    _FILE_OFFSET_BITS=64
    _LARGEFILE_SOURCE=1
    UNICODE=1
    _UNICODE=1
    ENV_HAVE_LOCALE=1
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    target_compile_options(7ZipCore PRIVATE -w)
endif()

# Build smoke test executable
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../Tests/smoke_test.cpp")
    add_executable(smoke_test "${CMAKE_CURRENT_SOURCE_DIR}/../Tests/smoke_test.cpp")
    target_link_libraries(smoke_test PRIVATE 7ZipCore)
    target_include_directories(smoke_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
endif()
