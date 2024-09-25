##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift.org project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

add_library(_SubprocessCShims STATIC
    platform_shims.c
#    string_shims.c
    process_shims.c
#    uuid.c
)

target_include_directories(_SubprocessCShims PUBLIC include)

set_property(GLOBAL APPEND PROPERTY SWIFT_FOUNDATION_EXPORTS _SubprocessCShims)

if(BUILD_SHARED_LIBS)
    set(install_directory swift)
else()
    set(install_directory swift_static)
endif()

# Copy Headers to known directory for direct client (XCTest) test builds
#file(COPY
#        include/
#    DESTINATION
#        ${CMAKE_BINARY_DIR}/_CModulesForClients/_SubprocessCShims)

# Install headers
install(DIRECTORY
            include/
        DESTINATION
            lib/${install_directory}/_SubprocessCShims)

if(NOT BUILD_SHARED_LIBS)
    get_swift_host_os(swift_os)
    install(TARGETS _SubprocessCShims
        ARCHIVE DESTINATION lib/${install_directory}/${swift_os}
        LIBRARY DESTINATION lib/${install_directory}/${swift_os}
        RUNTIME DESTINATION bin)
endif()

