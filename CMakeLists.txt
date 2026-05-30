cmake_minimum_required(VERSION 3.12)

project(finiteflow32 CXX C)

set(FFLOW_VERSION 2)
set(FFLOW_VERSION_MINOR 0)

set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release
        CACHE STRING "Build type: Debug|Release" FORCE)
endif()

option(BUILD_SHARED_LIBS "build shared libraries" ON)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_C_STANDARD 99)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

set(FFLOW_ENABLE_EXCEPTIONS OFF CACHE BOOL
    "Do not add compiler flags disabling exceptions")

set(FFLOW_USE_UINT32_PRIMES OFF CACHE BOOL
    "Use the FiniteFlow32 table of 32-bit primes instead of the upstream 63-bit table")

if(NOT(FFLOW_ENABLE_EXCEPTIONS))
    if(MSVC)
        add_compile_options($<$<COMPILE_LANGUAGE:CXX>:/EHs-c->)
    else()
        add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>)
    endif()
endif()

# Thread pool, enabled by default except on MacOS
if(APPLE)
    set(FFLOW_THREAD_POOL OFF CACHE BOOL
        "Use thread pools for parallel tasks")
else()
    set(FFLOW_THREAD_POOL ON CACHE BOOL
        "Use thread pools for parallel tasks")
endif()

# rpaths (see https://cmake.org/Wiki/CMake_RPATH_handling#Always_full_RPATH)

if (POLICY CMP0068)
    cmake_policy(SET CMP0068 NEW)
endif()
if(APPLE)
    set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
endif()
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
list(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib" isSystemDir)
if("${isSystemDir}" STREQUAL "-1")
    set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
endif("${isSystemDir}" STREQUAL "-1")


# external dependencies

set(FFLOW_USE_FLINT ON CACHE BOOL
    "Use FLINT to compute multiplicative inverses")
if (FFLOW_USE_FLINT)
    find_package(FLINT)
    if (FLINT_LIBRARY)
        include_directories(SYSTEM ${FLINT_INCLUDE_DIRS})
        include_directories(SYSTEM ${FLINT_INCLUDE_DIRS}/flint)
        set(LIBS ${LIBS} ${FLINT_TARGETS})
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DFFLOW_USE_FLINT=1")
    else()
        message("-- FLINT not found")
    endif()
endif()
if (NOT FLINT_LIBRARY)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DFFLOW_USE_FLINT=0")
endif()

find_package(GMP REQUIRED)
include_directories(SYSTEM ${GMP_INCLUDE_DIRS})
set(LIBS ${LIBS} ${GMP_TARGETS})

find_package(Threads)
set(LIBS ${LIBS} ${CMAKE_THREAD_LIBS_INIT})


# fflow library

include(TestBigEndian)
TEST_BIG_ENDIAN(FFLOW_BIG_ENDIAN)
configure_file(include/fflow/config.hh.in include/fflow/config.hh)

include_directories(
    BEFORE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${PROJECT_BINARY_DIR}/include
    )

set(FFLOW_SOURCES
    src/debug.cc
    src/function_cache.cc
    src/gcd.cc
    src/integer_math.cc
    src/matrix.cc
    src/multivariate_reconstruction.cc
    src/polynomial.cc
    src/primes.cc
    src/rational_function.cc
    src/univariate_reconstruction.cc
    src/algorithm.cc
    src/alg_linear_solver.cc
    src/alg_linear_fit.cc
    src/alg_reconstruction.cc
    src/alg_mp_reconstruction.cc
    src/ratfun_parser.cc
    src/ratexpr_parser.cc
    src/poly_reduction.cc
    src/alg_poly_reduction.cc
    src/alg_groebner.cc

    src/mp_functions.cc
    src/mp_gcd.cc
	src/mp_multivariate_reconstruction.cc

    src/format.cc
    src/ostream.cc
    src/spooky_v2.hh
    src/spooky_v2.cc

    #src/interface.cc
    src/json.cc
    src/graph.cc
    src/subgraph.cc
    src/alg_lists.cc
    src/alg_functions.cc
    src/analytic_solver.cc
    src/analytic_fit.cc
    src/numeric_solver.cc
    src/node_solver.cc
    src/subgraph_fit.cc
    src/numeric_fit.cc
    src/alg_laurent.cc
    src/subgraph_reconstruct.cc
    src/cached_subgraph.cc
    src/eval_count.cc
    src/ffmod.c

    src/capi.cc
    src/capi_native_ext.cc
    src/capi_custom_threads.cc

    src/ffuhash.h
    src/ffuhash.c
    src/WjCryptLib_Sha1.h
    src/WjCryptLib_Sha1.c
    )

set(FFLOW_HEADERS
    ${PROJECT_BINARY_DIR}/include/fflow/config.hh

    include/fflow/common.hh
    include/fflow/small_vector.hh
    include/fflow/refcounted_ptr.hh
    include/fflow/shared_array.hh
    include/fflow/debug.hh
    include/fflow/function_cache.hh
    include/fflow/gcd.hh
    include/fflow/integer_math.hh
    include/fflow/matrix.hh
    include/fflow/multivariate_reconstruction.hh
    include/fflow/multivariate_reconstruction_details.hh
    include/fflow/polynomial.hh
    include/fflow/primes.hh
    include/fflow/primes32.hh
    include/fflow/rational_function.hh
    include/fflow/univariate_reconstruction.hh
    include/fflow/ratfun_parser.hh
    include/fflow/ratexpr_parser.hh
    include/fflow/poly_reduction.hh
    include/fflow/alg_groebner.hh

    include/fflow/mp_common.hh
    include/fflow/mp_functions.hh
    include/fflow/mp_gcd.hh
	include/fflow/mp_multivariate_reconstruction.hh

    include/fflow/algorithm.hh
    include/fflow/alg_linear_solver.hh
    include/fflow/alg_linear_fit.hh
    include/fflow/alg_reconstruction.hh
    include/fflow/alg_mp_reconstruction.hh
    include/fflow/alg_poly_reduction.hh

    include/fflow/format.h
    include/fflow/ostream.h

    #include/fflow/interface.hh
    include/fflow/json.hh
    include/fflow/thread_pool.hh
    include/fflow/graph.hh
    include/fflow/subgraph.hh
    include/fflow/alg_lists.hh
    include/fflow/alg_functions.hh
    include/fflow/analytic_solver.hh
    include/fflow/numeric_solver.hh
    include/fflow/node_solver.hh
    include/fflow/analytic_fit.hh
    include/fflow/subgraph_fit.hh
    include/fflow/numeric_fit.hh
    include/fflow/alg_laurent.hh
    include/fflow/subgraph_reconstruct.hh
    include/fflow/cached_subgraph.hh
    include/fflow/eval_count.hh
    include/fflow/ffmod.h
    include/fflow/capi.h
    include/fflow/capi_native_ext.h
    include/fflow/capi_custom_threads.h
    )

set(FFLOW_INSTALL_INCLUDEDIR "include/finiteflow32" CACHE PATH
    "Installation path for public headers, relative to CMAKE_INSTALL_PREFIX")
set(FFLOW_MATHEMATICA_PACKAGE_INSTALL_DIR "share/finiteflow32/mathematica"
    CACHE PATH
    "Installation path for the Mathematica package, relative to CMAKE_INSTALL_PREFIX")
set(FFLOW_MATHEMATICA_LIBRARY_INSTALL_DIR "lib/finiteflow32/mathematica"
    CACHE PATH
    "Installation path for the Mathematica LibraryLink library, relative to CMAKE_INSTALL_PREFIX")

add_library(finiteflow32 ${FFLOW_SOURCES})
target_link_libraries(finiteflow32 ${LIBS})

install(FILES ${FFLOW_HEADERS} DESTINATION ${FFLOW_INSTALL_INCLUDEDIR}/fflow)
install(TARGETS finiteflow32 ARCHIVE DESTINATION lib LIBRARY DESTINATION lib RUNTIME DESTINATION bin)


# tests

set(TEST_TARGETS
    testjson
    testbench
    testfiniteflow32_arithmetic
    testpoly_reduction
    )

set(TEST_CTARGETS
    testcapi
    )

foreach(target ${TEST_TARGETS})
    add_executable(${target} tests/${target}.cc)
    set_target_properties(${target} PROPERTIES EXCLUDE_FROM_ALL TRUE)
    target_link_libraries(${target} finiteflow32 ${LIBS})
endforeach(target)

foreach(target ${TEST_CTARGETS})
    add_executable(${target} tests/${target}.c)
    set_target_properties(${target} PROPERTIES EXCLUDE_FROM_ALL TRUE)
    target_link_libraries(${target} finiteflow32 ${LIBS})
endforeach(target)

if(NOT TARGET tests)
  add_custom_target(tests)
  add_dependencies(tests ${TEST_TARGETS} ${TEST_CTARGETS})
endif()


# mathematica

set (CMAKE_MODULE_PATH
    "${CMAKE_SOURCE_DIR}/cmake/Mathematica" ${CMAKE_MODULE_PATH})

set(MATHLIBINSTALL "" CACHE PATH
    "Installation path for Mathematica interface")

set(FFLOW_MATHEMATICA_SOURCES
    mathlink/fflowmlink.cc
    )

set(FFLOW_MATHEMATICA ON CACHE BOOL
    "Build Mathematica interface")

if (FFLOW_MATHEMATICA)
    find_package(Mathematica COMPONENTS MathLink WolframLibrary)
endif()

if (Mathematica_FOUND)

    include_directories(${Mathematica_INCLUDE_DIRS})
    Mathematica_ADD_LIBRARY(finiteflow32mlink ${FFLOW_MATHEMATICA_SOURCES})
    target_link_libraries(finiteflow32mlink finiteflow32 ${LIBS}
        ${Mathematica_MathLink_LIBRARIES})
    if (Mathematica_MathLink_LINKER_FLAGS)
		set_target_properties(finiteflow32mlink PROPERTIES
            LINK_FLAGS "${Mathematica_MathLink_LINKER_FLAGS}")
	endif()
    Mathematica_ABSOLUTIZE_LIBRARY_DEPENDENCIES(finiteflow32mlink)
    install(FILES mathlink/FiniteFlow32.m
        DESTINATION "${FFLOW_MATHEMATICA_PACKAGE_INSTALL_DIR}")
    if (MATHLIBINSTALL)
        install(TARGETS finiteflow32mlink
            LIBRARY DESTINATION "${MATHLIBINSTALL}")
    elseif (FFLOW_MATHEMATICA_LIBRARY_INSTALL_DIR)
        install(TARGETS finiteflow32mlink
            LIBRARY DESTINATION "${FFLOW_MATHEMATICA_LIBRARY_INSTALL_DIR}")
    elseif (DEFINED Mathematica_USERBASE_DIR)
        foreach (_systemID ${Mathematica_SYSTEM_IDS})
            install(TARGETS finiteflow32mlink
                LIBRARY DESTINATION "${Mathematica_USERBASE_DIR}/SystemFiles/LibraryResources/${_systemID}")
        endforeach()
    else()
        message(WARNING "\
The Mathematica interface cannot be installed \
because no suitable installation path was found.  \
Please specify a path with the MATHLIBINSTALL variable\
during configuration."
            )
    endif()

elseif(FFLOW_MATHEMATICA)

    message(WARNING "\
The Mathematica interface cannot be installed \
because no suitable Mathematica installation was found."
        )

endif()


set(FFLOW_PYTHON OFF CACHE BOOL "Build Python interface")
set(FFLOW_PYTHON_INSTALL "" CACHE PATH
    "Installation path for Python interface")
if (FFLOW_PYTHON)
    find_package (Python3 COMPONENTS Interpreter Development)
    if (Python3_FOUND)
        file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/_python_gen)
        add_custom_command(
            DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/include/fflow/capi.h"
            "${CMAKE_CURRENT_SOURCE_DIR}/pythonapi/fflow_build.py"
            COMMAND
            ${Python3_EXECUTABLE}
            "${CMAKE_CURRENT_SOURCE_DIR}/pythonapi/fflow_build.py"
            "--source-only"
            OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_python_gen/_cffi_finiteflow32.c"
            WORKING_DIRECTORY "${PROJECT_BINARY_DIR}/_python_gen"
        )
        add_custom_target(
            fflow_python_interface_src ALL
            DEPENDS
            "${PROJECT_BINARY_DIR}/_python_gen/_cffi_finiteflow32.c"
        )
        Python3_add_library(_cffi_finiteflow32
            MODULE
            "${PROJECT_BINARY_DIR}/_python_gen/_cffi_finiteflow32.c"
        )
        add_dependencies(_cffi_finiteflow32 fflow_python_interface_src)
        target_link_libraries(_cffi_finiteflow32 PRIVATE finiteflow32 ${LIBS})
        if (FFLOW_PYTHON_INSTALL)
            install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/pythonapi/finiteflow32.py"
                DESTINATION ${FFLOW_PYTHON_INSTALL})
            install(TARGETS _cffi_finiteflow32
                DESTINATION ${FFLOW_PYTHON_INSTALL})
        else()
            execute_process(COMMAND ${Python3_EXECUTABLE} -m site --user-site
                OUTPUT_VARIABLE FFLOW_PYTHON_USER_SITE
                OUTPUT_STRIP_TRAILING_WHITESPACE)
            install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/pythonapi/finiteflow32.py"
                DESTINATION ${FFLOW_PYTHON_USER_SITE})
            install(TARGETS _cffi_finiteflow32
                DESTINATION ${FFLOW_PYTHON_USER_SITE})
        endif()
    endif()
endif()


# uninstall
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
    IMMEDIATE @ONLY)
add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
