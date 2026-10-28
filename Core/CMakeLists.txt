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

# Build OBJECT library so object files can be directly linked without static archive stripping
add_library(7ZipCore_obj OBJECT ${SOURCES_LIST})

set_target_properties(7ZipCore_obj PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_include_directories(7ZipCore_obj PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/Common"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/Windows"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/7zip"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/CPP/7zip/Common"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/7zip/C"
)

target_compile_definitions(7ZipCore_obj PUBLIC
    Z7_PROG_VARIANT_Z=1
    _REENTRANT=1
    _FILE_OFFSET_BITS=64
    _LARGEFILE_SOURCE=1
    UNICODE=1
    _UNICODE=1
    ENV_HAVE_LOCALE=1
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    target_compile_options(7ZipCore_obj PRIVATE -w)
endif()

# Static library target for external consumers
add_library(7ZipCore STATIC $<TARGET_OBJECTS:7ZipCore_obj>)
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

# Build smoke test executable directly with object files to preserve static self-registrations
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../Tests/smoke_test.cpp")
    add_executable(smoke_test "${CMAKE_CURRENT_SOURCE_DIR}/../Tests/smoke_test.cpp" $<TARGET_OBJECTS:7ZipCore_obj>)
    target_include_directories(smoke_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    if(APPLE)
        target_link_libraries(smoke_test PRIVATE pthread)
    elseif(UNIX)
        target_link_libraries(smoke_test PRIVATE pthread dl)
    endif()
endif()
