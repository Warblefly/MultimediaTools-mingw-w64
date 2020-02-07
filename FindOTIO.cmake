# Find the OpenTimeIO library.
#
# This module defines the following variables:
#
# * OTIO_FOUND
# * OTIO_INCLUDE_DIRS
# * OTIO_LIBRARIES
# * OTIO_DEFINES
#
# This module defines the following imported targets:
#
# * OTIO::OTIO
#
# This module defines the following interfaces:
#
# * OTIO

find_path(OTIO_INCLUDE_DIR
	NAMES linearTimeWarp.h
    PATH_SUFFIXES opentimelineio)
set(OTIO_INCLUDE_DIRS
    ${OTIO_INCLUDE_DIR})

find_library(
	OTIO_LIBRARY NAMES opentimelineio
	PATH_SUFFIXES static)
set(OTIO_LIBRARIES
    ${OTIO_LIBRARY})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
    OTIO
    REQUIRED_VARS OTIO_INCLUDE_DIR OTIO_LIBRARY)
mark_as_advanced(OTIO_INCLUDE_DIR OTIO_LIBRARY)

set(OTIO_DEFINES)
if(NOT OTIO_SHARED_LIBS)
	set(OTIO_DEFINES opentimelineio_STATIC)
endif()

if(OTIO_FOUND AND NOT TARGET OTIO::OTIO)
    add_library(OTIO::OTIO UNKNOWN IMPORTED)
    set_target_properties(OTIO::OTIO PROPERTIES
        IMPORTED_LOCATION "${OTIO_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${OTIO_INCLUDE_DIRS}"
		INTERFACE_COMPILE_DEFINITIONS "${OTIO_DEFINES}")
endif()
if(OTIO_FOUND AND NOT TARGET OTIO)
    add_library(OTIO INTERFACE)
    target_link_libraries(OTIO INTERFACE OTIO::OTIO)
endif()

