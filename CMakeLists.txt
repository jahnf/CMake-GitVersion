cmake_minimum_required(VERSION 3.1)

# Add directory of GitVersion to the cmake module path.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Now it can be included like this:
include(GitVersion)

# Examples project
project(GitVersion-Demo LANGUAGES CXX)

# For examples see the 'example' diretory
add_subdirectory(example)

