# CMake-GitVersion.
# CMake module for generating version information using information from git with fallback options
# when building without git (e.g. when building from sources with exported archives) dsdf
# Best suited with git-flow workflows
# - See also: https://www.atlassian.com/de/git/tutorials/comparing-workflows/gitflow-workflow
#
# Follows [semantic versioning](https://semver.org)
# and creates version strings that can be used by debian and rpm packages.
#
# Originally written for building dcled-hidapi - userland driver for the Dream Cheeky LED Message Board
# https://github.com/jahnf/dcled-hidapi
#
# Since then often reused, extended and adjusted in multiple projects
# (also used in Projecteur: https://github.com/jahnf/Projecteur).
# Now released as it's own project for better reusability and documentation.
#
# Distributed under the MIT License. See accompanying LICENSE file.

# Definition:
# LAST_TAG_VERSION = latest tagged version (e.g. 1.2.0 for v1.2.0) or 0.0.0 if it does not exist.
#
# Version Number rules:
# - on 'master':  X.Y.Z[-DIST] (using LAST_TAG_VERSION),
#                 while DIST should always be 0 on the master branch
# - on 'develop' and other branches : X.Y.Z-ALPHA_FLAG.DIST (using LAST_TAG_VERSION, incrementing Y by 1)
# - on release branches: X.Y.Z-RC_FLAG.DIST (using semver from release branch name
#                                            or XYZ like on develop if not possible)
#                        DIST is either calculated to last tag or to the closest rc-X.Y.Z tag

# * DISTANCE is only added on versions from master branch when != 0
# * On all other branches DISTANCE is always added.
# * All version numbers besides the ones from master have a pre-release identifier set.
# * When creating the version string and the PATCH number is 0 - the patch number is omitted.
#  (e.g. 1.2.0 will be 1.2)

### Configuration - this may be adjusted to the personal and project requirements
set(VERSION_TAG_PREFIX v)     # Should be the same as configured in git-flow
set(VERSION_ALPHA_FLAG alpha) # Pre-release identifier for all builds besides release and hotfix branches
set(VERSION_RC_FLAG rc)       # Pre-release identifier for all builds from release and hotfix branches
set(VERSION_RC_START_TAG_PREFIX "rc-") # If available tags with the given prefix are used for distance calculation on release branches.
set(RC_BRANCH_PREFIX release) # e.g. release/0.2
set(HOTFIX_BRANCH_PREFIX hotfix) # e.g. hotfix/2.0.3


set(_GitVersion_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")



# --------------------------------------------------------------------------------------------------
function(add_version_info)
  set(options DEFAULT_TEMPLATES) # no default templates option
  set(oneValueArgs
    TARGET    # The build target
    DIRECTORY # Directory from which to get the git version info
  )
  set(multiValueArgs TEMPLATES) # Templates that are configured and added to the target
  set(requiredArgs TARGET DIRECTORY)
  cmake_parse_arguments(VI "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  foreach(arg IN LISTS requiredArgs)
    if("${VI_${arg}}" STREQUAL "")
      message(FATAL_ERROR "Required argument '${arg}' is not set.")
    endif()
  endforeach()

  if(NOT TARGET ${VI_TARGET})
    message(FATAL_ERROR "Argument 'TARGET' needs to be a valid target.")
  endif()

  string(MAKE_C_IDENTIFIER "${VI_TARGET}" prefix)

  if(VI_DEFAULT_TEMPLATES)
    set(DEFAULT_TEMPLATES DEFAULT_TEMPLATES)
  endif()

  list(LENGTH VI_TEMPLATES NUM_TEMPLATES)
  if(NUM_TEMPLATE_ARGS NOT EQUAL 0)
    set(TEMPLATES TEMPLATES)
  endif()

  add_version_info_custom_prefix(TARGET ${VI_TARGET}
                                 PREFIX ${prefix}
                                 DIRECTORY ${VI_DIRECTORY}
                                 ${TEMPLATES} ${VI_TEMPLATES}
                                 ${DEFAULT_TEMPLATES})
endfunction()


# Get the version information for a directory, sets the following variables
# ${prefix}_VERSION_SUCCESS // 0 on error (e.g. git not found), 1 on success
# ${prefix}_VERSION_MAJOR
# ${prefix}_VERSION_MINOR
# ${prefix}_VERSION_PATCH
# ${prefix}_VERSION_FLAG
# ${prefix}_VERSION_DISTANCE
# ${prefix}_VERSION_SHORTHASH
# ${prefix}_VERSION_FULLHASH
# ${prefix}_VERSION_ISDIRTY // 0 or 1 if tree has local modifications
# ${prefix}_VERSION_STRING // Full version string, e.g. 1.2.3-rc.239
#
# A created version number can be overruled if the following variables are set and the version number is GREATER
# than the dynamically created one.
# - ${prefix}_CUSTOM_VERSION_MAJOR
# - ${prefix}_CUSTOM_VERSION_MINOR
# - ${prefix}_CUSTOM_VERSION_PATCH
#
# A version 'type' (release or develop) in case the branch cannot be determined via git
# - #{prefix}_FALLBACK_VERSION_TYPE

# The environment variable FALLBACK_BRANCH will be used if the branch cannot be determined

function(get_version_info prefix directory)
  set(${prefix}_VERSION_SUCCESS 0 PARENT_SCOPE)
  set(${prefix}_VERSION_MAJOR 0)
  set(${prefix}_VERSION_MINOR 0)
  set(${prefix}_VERSION_PATCH 0)
  set(${prefix}_VERSION_BRANCH unknown)
  set(${prefix}_VERSION_FLAG unknown)
  set(${prefix}_VERSION_DISTANCE 0)
  set(${prefix}_VERSION_STRING 0.0.0-unknown)
  set(${prefix}_VERSION_ISDIRTY 0 PARENT_SCOPE)

  if("${${prefix}_CUSTOM_VERSION_MAJOR}" STREQUAL "")
    set(${prefix}_CUSTOM_VERSION_MAJOR 0)
  endif()
  if("${${prefix}_CUSTOM_VERSION_MINOR}" STREQUAL "")
    set(${prefix}_CUSTOM_VERSION_MINOR 0)
  endif()
  if("${${prefix}_CUSTOM_VERSION_PATCH}" STREQUAL "")
    set(${prefix}_CUSTOM_VERSION_PATCH 0)
  endif()

  find_package(Git)
  if(GIT_FOUND)
    # Get the version info from the last tag (using the configured version tag prefix)
    execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags --match "${VERSION_TAG_PREFIX}[0-9].[0-9]*"
      RESULT_VARIABLE result
      OUTPUT_VARIABLE GIT_TAG_VERSION
      ERROR_VARIABLE error_out
      OUTPUT_STRIP_TRAILING_WHITESPACE
      WORKING_DIRECTORY ${directory}
    )
    if(result EQUAL 0)
      # Extract version major, minor, patch from the result
      if(GIT_TAG_VERSION MATCHES "^${VERSION_TAG_PREFIX}?([0-9]+)\\.([0-9]+)(\\.([0-9]+))?(-([0-9]+))?.*$")
        set(${prefix}_VERSION_MAJOR ${CMAKE_MATCH_1})
        set(${prefix}_VERSION_MINOR ${CMAKE_MATCH_2})
        if(NOT ${CMAKE_MATCH_4} STREQUAL "")
          set(${prefix}_VERSION_PATCH ${CMAKE_MATCH_4})
        endif()
        if(NOT ${CMAKE_MATCH_6} STREQUAL "")
          set(${prefix}_VERSION_DISTANCE ${CMAKE_MATCH_6})
        endif()
      endif()
    else()
      # git describe return with error - just get the distance
      execute_process(COMMAND ${GIT_EXECUTABLE} rev-list --count HEAD
        RESULT_VARIABLE result
        OUTPUT_VARIABLE GIT_DISTANCE
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_VARIABLE error_out
        WORKING_DIRECTORY ${directory}
      )
      if(result EQUAL 0)
        set(${prefix}_VERSION_DISTANCE ${GIT_DISTANCE})
      endif()
    endif()

    # Check for local modifications ...
    execute_process(COMMAND ${GIT_EXECUTABLE} describe --always --dirty
      RESULT_VARIABLE result
      OUTPUT_VARIABLE GIT_ALWAYS_VERSION
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE error_out
      WORKING_DIRECTORY ${directory}
    )
    if(result EQUAL 0)
      if(GIT_ALWAYS_VERSION MATCHES "^.*-dirty$")
        set(${prefix}_VERSION_ISDIRTY 1 PARENT_SCOPE)
      endif()
    endif()

    # Check the branch we are on
    execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
      RESULT_VARIABLE result
      OUTPUT_VARIABLE GIT_BRANCH
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE error_out
      WORKING_DIRECTORY ${directory}
    )

    if(result EQUAL 0)
      if("${GIT_BRANCH}" STREQUAL "HEAD"
         AND NOT "$ENV{FALLBACK_BRANCH}" STREQUAL "")
         set(GIT_BRANCH "$ENV{FALLBACK_BRANCH}")
      endif()

      set(${prefix}_VERSION_BRANCH "${GIT_BRANCH}")
      set(${prefix}_VERSION_BRANCH "${GIT_BRANCH}" PARENT_SCOPE)

      # Check for release branch
      string(LENGTH ${RC_BRANCH_PREFIX} PREFIX_LEN)
      string(SUBSTRING ${GIT_BRANCH} 0 ${PREFIX_LEN} COMPARE_PREFIX)
      string(COMPARE EQUAL ${RC_BRANCH_PREFIX} ${COMPARE_PREFIX} ON_RELEASE_BRANCH)
      # Check for hotfix branch
      string(LENGTH ${HOTFIX_BRANCH_PREFIX} PREFIX_LEN)
      string(SUBSTRING ${GIT_BRANCH} 0 ${PREFIX_LEN} COMPARE_PREFIX)
      string(COMPARE EQUAL ${HOTFIX_BRANCH_PREFIX} ${COMPARE_PREFIX} ON_HOTFIX_BRANCH)
      # Check for master branch
      string(COMPARE EQUAL "master" ${GIT_BRANCH} ON_MASTER)

      if(ON_RELEASE_BRANCH)
        set(${prefix}_VERSION_FLAG ${VERSION_RC_FLAG})
        set(RC_VERSION_MAJOR 0)
        set(RC_VERSION_MINOR 0)
        set(RC_VERSION_PATCH 0)
        # Check release branch name for version information (e.g. release/0.8)
        if(GIT_BRANCH MATCHES "^${RC_BRANCH_PREFIX}.*([0-9]+)\\.([0-9]+)(\\.([0-9]+))?.*$")
          set(RC_VERSION_MAJOR ${CMAKE_MATCH_1})
          set(RC_VERSION_MINOR ${CMAKE_MATCH_2})
          if(NOT ${CMAKE_MATCH_4} STREQUAL "")
            set(RC_VERSION_PATCH ${CMAKE_MATCH_4})
          endif()
        endif()

        # If the release branch version is greater, use that version...
        if("${RC_VERSION_MAJOR}.${RC_VERSION_MINOR}.${RC_VERSION_PATCH}" VERSION_GREATER
            "${${prefix}_VERSION_MAJOR}.${${prefix}_VERSION_MINOR}.${${prefix}_VERSION_PATCH}")
          set(${prefix}_VERSION_MAJOR ${RC_VERSION_MAJOR})
          set(${prefix}_VERSION_MINOR ${RC_VERSION_MINOR})
          set(${prefix}_VERSION_PATCH ${RC_VERSION_PATCH})
        else() # ... else auto increment the version minor number
          # Auto increment minor number, patch = 0
          MATH(EXPR ${prefix}_VERSION_MINOR "${${prefix}_VERSION_MINOR}+1")
          set(${prefix}_VERSION_PATCH 0)
        endif()

        # Try to get distance from last rc start tag
        execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags --match "${VERSION_RC_START_TAG_PREFIX}[0-9].[0-9]*"
          RESULT_VARIABLE result
          OUTPUT_VARIABLE GIT_RC_TAG_VERSION
          ERROR_VARIABLE error_out
          OUTPUT_STRIP_TRAILING_WHITESPACE
          WORKING_DIRECTORY ${directory}
        )
        if(result EQUAL 0)
          if(GIT_RC_TAG_VERSION MATCHES "^${VERSION_RC_START_TAG_PREFIX}?([0-9]+)\\.([0-9]+)(\\.([0-9]+))?(-([0-9]+))?.*$")
            if(NOT ${CMAKE_MATCH_6} STREQUAL "")
              set(${prefix}_VERSION_DISTANCE ${CMAKE_MATCH_6})
            else()
              set(${prefix}_VERSION_DISTANCE 0)
            endif()
          endif()
        endif()

      elseif(ON_HOTFIX_BRANCH)
        set(${prefix}_VERSION_FLAG ${VERSION_RC_FLAG})
          set(RC_VERSION_MAJOR 0)
          set(RC_VERSION_MINOR 0)
          set(RC_VERSION_PATCH 0)
          if(GIT_BRANCH MATCHES "^${RC_BRANCH_PREFIX}.*([0-9]+)\\.([0-9]+)(\\.([0-9]+))?.*$")
            set(RC_VERSION_MAJOR ${CMAKE_MATCH_1})
            set(RC_VERSION_MINOR ${CMAKE_MATCH_2})
            if(NOT ${CMAKE_MATCH_4} STREQUAL "")
              set(RC_VERSION_PATCH ${CMAKE_MATCH_4})
            endif()
          endif()

          if("${RC_VERSION_MAJOR}.${RC_VERSION_MINOR}.${RC_VERSION_PATCH}" VERSION_GREATER
              "${${prefix}_VERSION_MAJOR}.${${prefix}_VERSION_MINOR}.${${prefix}_VERSION_PATCH}")
            set(${prefix}_VERSION_MAJOR ${RC_VERSION_MAJOR})
            set(${prefix}_VERSION_MINOR ${RC_VERSION_MINOR})
            set(${prefix}_VERSION_PATCH ${RC_VERSION_PATCH})
          else()
            # Auto increment patch number
            MATH(EXPR ${prefix}_VERSION_PATCH "${${prefix}_VERSION_PATCH}+1")
          endif()
      elseif(ON_MASTER)
       set(${prefix}_VERSION_FLAG "")
      endif()
    endif()

    if(NOT ON_MASTER AND NOT ON_RELEASE_BRANCH AND NOT ON_HOTFIX_BRANCH)
      # Auto increment version number, set alpha flag
      MATH(EXPR ${prefix}_VERSION_MINOR "${${prefix}_VERSION_MINOR}+1")
      set(${prefix}_VERSION_PATCH 0)
      set(${prefix}_VERSION_FLAG ${VERSION_ALPHA_FLAG})
    endif()

    set(${prefix}_VERSION_FLAG ${${prefix}_VERSION_FLAG} PARENT_SCOPE)
    set(${prefix}_VERSION_DISTANCE ${${prefix}_VERSION_DISTANCE} PARENT_SCOPE)

    execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
      RESULT_VARIABLE resultSH
      OUTPUT_VARIABLE GIT_SHORT_HASH
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE error_out
      WORKING_DIRECTORY ${directory}
    )
    if(resultSH EQUAL 0)
      set(${prefix}_VERSION_SHORTHASH ${GIT_SHORT_HASH} PARENT_SCOPE)
    else()
      message(STATUS "Version-Info: Could not fetch short version hash.")
      set(${prefix}_VERSION_SHORTHASH "unknown" PARENT_SCOPE)
    endif()

    execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
      RESULT_VARIABLE resultFH
      OUTPUT_VARIABLE GIT_FULL_HASH
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE error_out
      WORKING_DIRECTORY ${directory}
    )
    if(resultFH EQUAL 0)
      set(${prefix}_VERSION_FULLHASH ${GIT_FULL_HASH} PARENT_SCOPE)
    else()
      message(STATUS "Version-Info: Could not fetch full version hash.")
      set(${prefix}_VERSION_FULLHASH "unknown" PARENT_SCOPE)
    endif()

    if(resultSH EQUAL 0 AND resultFH EQUAL 0)
      set(${prefix}_VERSION_SUCCESS 1 PARENT_SCOPE)
    endif()
  else() # Git not found ...
    message(STATUS "Version-Info: Git not found. Possible incomplete version information.")
  endif()

  if("${${prefix}_VERSION_BRANCH}" STREQUAL "unknown" OR "${${prefix}_VERSION_BRANCH}" STREQUAL "")
    if("${${prefix}_FALLBACK_VERSION_TYPE}" STREQUAL "release")
      set(ON_MASTER ON)
      set(${prefix}_VERSION_FLAG "")
      set(${prefix}_VERSION_FLAG "" PARENT_SCOPE)
    endif()
    set(${prefix}_VERSION_BRANCH "not-within-git-repo" PARENT_SCOPE)
  endif()

  # Check if overrule version is greater than dynamically created one
  if("${${prefix}_CUSTOM_VERSION_MAJOR}.${${prefix}_CUSTOM_VERSION_MINOR}.${${prefix}_CUSTOM_VERSION_PATCH}" VERSION_GREATER
  "${${prefix}_VERSION_MAJOR}.${${prefix}_VERSION_MINOR}.${${prefix}_VERSION_PATCH}")
    set(${prefix}_VERSION_MAJOR ${${prefix}_CUSTOM_VERSION_MAJOR})
    set(${prefix}_VERSION_MINOR ${${prefix}_CUSTOM_VERSION_MINOR})
    set(${prefix}_VERSION_PATCH ${${prefix}_CUSTOM_VERSION_PATCH})
  endif()

  set(${prefix}_VERSION_MAJOR ${${prefix}_VERSION_MAJOR} PARENT_SCOPE)
  set(${prefix}_VERSION_MINOR ${${prefix}_VERSION_MINOR} PARENT_SCOPE)
  set(${prefix}_VERSION_PATCH ${${prefix}_VERSION_PATCH} PARENT_SCOPE)
  set(${prefix}_VERSION_DISTANCE ${${prefix}_VERSION_DISTANCE} PARENT_SCOPE)

  # Build version string...
  set(VERSION_STRING "${${prefix}_VERSION_MAJOR}.${${prefix}_VERSION_MINOR}")
  if(NOT ${${prefix}_VERSION_PATCH} EQUAL 0)
    set(VERSION_STRING "${VERSION_STRING}.${${prefix}_VERSION_PATCH}")
  endif()
  if(NOT ON_MASTER OR NOT ${${prefix}_VERSION_DISTANCE} EQUAL 0)
    set(VERSION_STRING "${VERSION_STRING}-${${prefix}_VERSION_FLAG}")
  endif()
  if(NOT ${${prefix}_VERSION_FLAG} STREQUAL "")
    set(VERSION_STRING "${VERSION_STRING}.")
  endif()
  if(NOT ON_MASTER OR (NOT ON_MASTER AND NOT ${${prefix}_VERSION_DISTANCE} EQUAL 0))
    set(VERSION_STRING "${VERSION_STRING}${${prefix}_VERSION_DISTANCE}")
  endif()
  set(${prefix}_VERSION_STRING "${VERSION_STRING}" PARENT_SCOPE)
endfunction()

# Add version information to a target, header and source file are configured from templates.
#  (GitVersion.h.in and GitVersion.cc.in if no other templates are defined)
# Variables available to input templates
# @PREFIX@ = target prefix name given in the function call, must be a valid C-identifier
# @VERSION_MAJOR@, @VERSION_MINOR@, @VERSION_PATCH@, @VERSION_FLAG@, @VERSION_DISTANCE@
# @VERSION_SHORTHASH@, @VERSION_FULLHASH@, @VERSION_STRING@, @VERSION_ISDIRTY, @VERSION_BRANCH@
function(add_version_info_custom_prefix)
  set(options DEFAULT_TEMPLATES) # add default templates option
  set(oneValueArgs
    TARGET    # The build target
    PREFIX    # The prefix/name for templates
    DIRECTORY # Directory from which to get the git version info
  )
  set(multiValueArgs TEMPLATES) # Templates that are configured and added to the target
  set(requiredArgs TARGET DIRECTORY)
  cmake_parse_arguments(VI "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  foreach(arg IN LISTS requiredArgs)
  if("${VI_${arg}}" STREQUAL "")
    message(FATAL_ERROR "Required argument '${arg}' is not set.")
  endif()
  endforeach()

  if(NOT TARGET ${VI_TARGET})
  message(FATAL_ERROR "Argument 'TARGET' needs to be a valid target.")
  endif()

  if(VI_DEFAULT_TEMPLATES)
    # Add default templates
    list(APPEND VI_TEMPLATES "${_GitVersion_DIRECTORY}/GitVersion.h.in")
    list(APPEND VI_TEMPLATES "${_GitVersion_DIRECTORY}/GitVersion.cc.in")
  endif()
  string(MAKE_C_IDENTIFIER "${VI_TARGET}" targetid)

  # Set default values, in case sth goes wrong badly
  set(VERSION_MAJOR 0)
  set(VERSION_MINOR 0)
  set(VERSION_PATCH 0)
  set(VERSION_FLAG unknown)
  set(VERSION_DISTANCE 0)
  set(VERSION_SHORTHASH unknown)
  set(VERSION_FULLHASH unknown)
  set(VERSION_STRING "0.0-unknown.0")
  set(VERSION_ISDIRTY 0)
  set(VERSION_BRANCH unknown)
  set(output_dir "${CMAKE_CURRENT_BINARY_DIR}/version/${targetid}")

  get_target_property(TARGET_VMAJOR ${VI_TARGET} VERSION_MAJOR)
  if(TARGET_VMAJOR)
    set(${VI_PREFIX}_CUSTOM_VERSION_MAJOR ${TARGET_VMAJOR})
  endif()
  get_target_property(TARGET_VMINOR ${VI_TARGET} VERSION_MINOR)
  if(TARGET_VMINOR)
    set(${VI_PREVIX}_CUSTOM_VERSION_MINOR ${TARGET_VMINOR})
    set(VERSION_MINOR ${TARGET_VMINOR})
  endif()
  get_target_property(TARGET_VPATCH ${VI_TARGET} VERSION_PATCH)
  if(TARGET_VPATCH)
    set(${VI_PREFIX}_CUSTOM_VERSION_PATCH ${TARGET_VPATCH})
  endif()
  get_target_property(TARGET_VTYPE ${VI_TARGET} VERSION_TYPE)
  if(TARGET_VTYPE)
    set(${VI_PREFIX}_FALLBACK_VERSION_TYPE ${TARGET_VTYPE})
  endif()

  include(ArchiveVersionInfo_${VI_PREFIX} OPTIONAL RESULT_VARIABLE ARCHIVE_VERSION_PRESENT)
  if(ARCHIVE_VERSION_PRESENT AND ${VI_PREFIX}_VERSION_SUCCESS)
    message(STATUS "Info: Version information from archive file.")
  else()
    get_version_info(${VI_PREFIX} "${directory}")
    if("${${VI_PREFIX}_VERSION_FULLHASH}" STREQUAL "unknown"
       OR "${${VI_PREFIX}_VERSION_SHORTHASH}" STREQUAL "unknown"
       OR "${${VI_PREFIX}_VERSION_FULLHASH}" STREQUAL ""
       OR "${${VI_PREFIX}_VERSION_SHORTHASH}" STREQUAL "")
       include(ArchiveExportInfo OPTIONAL RESULT_VARIABLE GIT_EXPORT_INFO_FILE_PRESENT)
       if("${GIT_EXPORT_VERSION_SHORTHASH}" MATCHES "(.?Format:).*")
         set(HAS_GIT_EXPORT_INFO OFF)
       endif()
       if(GIT_EXPORT_INFO_FILE_PRESENT AND HAS_GIT_EXPORT_INFO)
         message(STATUS "Using ArchiveExportInfo as fallback for version info.")
         set(${VI_PREFIX}_VERSION_SHORTHASH "${GIT_EXPORT_VERSION_SHORTHASH}")
         set(${VI_PREFIX}_VERSION_FULLHASH "${GIT_EXPORT_VERSION_FULLHASH}")
         set(${VI_PREFIX}_VERSION_BRANCH "${GIT_EXPORT_VERSION_BRANCH}")
         if("${${VI_PREFIX}_VERSION_BRANCH}" MATCHES ".*[ \t]+[->]+[\t ]+(.*)([,]?.*)")
           set(${VI_PREFIX}_VERSION_BRANCH "${CMAKE_MATCH_1}")
         elseif("${${VI_PREFIX}_VERSION_BRANCH}" MATCHES ".*,[ \t](.*)")
           if("${CMAKE_MATCH_1}" STREQUAL "master")
             set(ON_MASTER ON)
           endif()
         endif()
         # Check for release branch
         string(LENGTH ${RC_BRANCH_PREFIX} PREFIX_LEN)
         string(SUBSTRING ${${VI_PREFIX}_VERSION_BRANCH} 0 ${PREFIX_LEN} COMPARE_PREFIX)
         string(COMPARE EQUAL ${RC_BRANCH_PREFIX} ${COMPARE_PREFIX} ON_RELEASE_BRANCH)
         # Check for hotfix branch
         string(LENGTH ${HOTFIX_BRANCH_PREFIX} PREFIX_LEN)
         string(SUBSTRING ${${VI_PREFIX}_VERSION_BRANCH} 0 ${PREFIX_LEN} COMPARE_PREFIX)
         string(COMPARE EQUAL ${HOTFIX_BRANCH_PREFIX} ${COMPARE_PREFIX} ON_HOTFIX_BRANCH)
         # Check for master branch
         if(NOT ON_MASTER)
           string(COMPARE EQUAL "master" ${${VI_PREFIX}_VERSION_BRANCH} ON_MASTER)
         endif()
         if(ON_MASTER)
           set(${VI_PREFIX}_VERSION_FLAG "")
         elseif(ON_RELEASE_BRANCH)
           set(${VI_PREFIX}_VERSION_FLAG "${VERSION_RC_FLAG}")
         elseiF(ON_HOTFIX_BRANCH)
           set(${VI_PREFIX}_VERSION_FLAG "hotfix")
         else()
           set(${VI_PREFIX}_VERSION_FLAG "${VERSION_ALPHA_FLAG}")
         endif()
         # Build version string...
         set(VERSION_STRING "${${VI_PREFIX}_VERSION_MAJOR}.${${VI_PREFIX}_VERSION_MINOR}")
         if(NOT ${${VI_PREFIX}_VERSION_PATCH} EQUAL 0)
           set(VERSION_STRING "${VERSION_STRING}.${${VI_PREFIX}_VERSION_PATCH}")
         endif()
         if(NOT ON_MASTER OR NOT ${${VI_PREFIX}_VERSION_DISTANCE} EQUAL 0)
           set(VERSION_STRING "${VERSION_STRING}-${${VI_PREFIX}_VERSION_FLAG}")
         endif()
         if(NOT ${${VI_PREFIX}_VERSION_FLAG} STREQUAL "")
           set(VERSION_STRING "${VERSION_STRING}.")
         endif()
         if(NOT ON_MASTER OR (NOT ON_MASTER AND NOT ${${VI_PREFIX}_VERSION_DISTANCE} EQUAL 0))
           set(VERSION_STRING "${VERSION_STRING}${${VI_PREFIX}_VERSION_DISTANCE}")
         endif()
         set(${VI_PREFIX}_VERSION_STRING "${VERSION_STRING}")
      endif()
    endif()
  endif()

  if(${${VI_PREFIX}_VERSION_SUCCESS})
    # All informations gathered via git
  else()
    message(STATUS "Version-Info: Failure during version retrieval. Possible incomplete version information!")
  endif()
  # Test if we are building from an archive that has generated version information
  set(VERSION_MAJOR ${${VI_PREFIX}_VERSION_MAJOR})
  set(VERSION_MINOR ${${VI_PREFIX}_VERSION_MINOR})
  set(VERSION_PATCH ${${VI_PREFIX}_VERSION_PATCH})
  set(VERSION_FLAG ${${VI_PREFIX}_VERSION_FLAG})
  set(VERSION_DISTANCE ${${VI_PREFIX}_VERSION_DISTANCE})
  set(VERSION_SHORTHASH ${${VI_PREFIX}_VERSION_SHORTHASH})
  set(VERSION_FULLHASH ${${VI_PREFIX}_VERSION_FULLHASH})
  set(VERSION_STRING ${${VI_PREFIX}_VERSION_STRING})
  set(VERSION_ISDIRTY ${${VI_PREFIX}_VERSION_ISDIRTY})
  set(VERSION_BRANCH ${${VI_PREFIX}_VERSION_BRANCH})
  set_target_properties(${target} PROPERTIES
    VERSION_MAJOR "${VERSION_MAJOR}"
    VERSION_MINOR "${VERSION_MINOR}"
    VERSION_PATCH "${VERSION_PATCH}"
    VERSION_FLAG "${VERSION_FLAG}"
    VERSION_DISTANCE "${VERSION_DISTANCE}"
    VERSION_SHORTHASH "${VERSION_SHORTHASH}"
    VERSION_FULLHASH "${VERSION_FULLHASH}"
    VERSION_STRING "${VERSION_STRING}"
    VERSION_ISDIRTY "${VERSION_ISDIRTY}"
    VERSION_BRANCH "${VERSION_BRANCH}"
  )

  set(TARGET ${VI_PREFIX})
  set(PREFIX ${VI_PREFIX})
  foreach(template_file ${VI_TEMPLATES})
    if(template_file MATCHES "(.*)(\.in)$")
      get_filename_component(output_basename "${CMAKE_MATCH_1}" NAME)
    else()
      get_filename_component(output_basename "${template_file}" NAME)
    endif()
    set(output_file "${output_dir}/${VI_PREFIX}-${output_basename}")
    configure_file("${template_file}" "${output_file}")
    list(APPEND output_files "${output_file}")
  endforeach()

  configure_file("${_GitVersion_DIRECTORY}/ArchiveVersionInfo.cmake.in"
                 "archive_append/cmake/modules/ArchiveVersionInfo_${VI_PREFIX}.cmake" @ONLY)

  get_target_property(type ${target} TYPE)
  if(type STREQUAL "SHARED_LIBRARY")
    set_target_properties(${target} PROPERTIES SOVERSION "${VERSION_MAJOR}.${VERSION_MINOR}")
    set_property(TARGET ${target} PROPERTY VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
  endif()
  if

  # If any templates where configured, add them to the project sources
  list(LENGTH output_files NUM_CONFIGURED_FILES)
  if(NUM_TEMPLATE_ARGS NOT EQUAL 0)
    set_property(TARGET ${target} APPEND PROPERTY SOURCES ${output_files})
    target_include_directories(${target} PUBLIC $<BUILD_INTERFACE:${output_dir}>)
  endif()
  message(STATUS "Version info for '${target}': ${VERSION_STRING}")
endfunction()

