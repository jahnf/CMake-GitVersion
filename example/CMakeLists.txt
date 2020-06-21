cmake_minimum_required(VERSION 3.1)

# Example executable target
add_executable(example example.cc)
add_version_info(TARGET example)

# Example executable target, with fallback/starting version
add_executable(example-2 example.cc)
# Setting version information, this is used as the version if it is greater than the automatically
# generated from git tags and used as fallback if no git information can be aquired
# (e.g. git not available, sources are a git archive export)
set_target_properties(example-2
  PROPERTIES
    VERSION_MAJOR 80
    VERSION_MINOR 11
    VERSION_PATCH 4
    VERSION_TYPE develop
)
add_version_info(TARGET example-2 PREFIX example)

# Example on adding additional version information via resource file to an executable on Windows
if (WIN32)
  add_version_info(TARGET example-2 PREFIX example TEMPLATES "example-win.rc.in")
endif()

# Example of a shared library
add_library(example-lib SHARED example-shared.cc)
add_version_info(TARGET example-lib)


# Example of version info in a static library used in multiple targets
add_library(versionlib STATIC versionlib.cc)
add_version_info(TARGET versionlib PREFIX example)

# Targets using the static version lib
add_executable(example-3 example.cc)
target_link_libraries(example-3 PRIVATE versionlib)

add_executable(example-4 example.cc)
target_link_libraries(example-4 PRIVATE versionlib)
