#include <iostream>

#include <example_lib-GitVersion.h>

void print_version_of_lib()
{
  std::cout << "| CMake-GitVersion library version"<< std::endl;
  std::cout << "| - version_string: " << example_lib::version_string() << std::endl;
  std::cout << "| - version_branch: " << example_lib::version_branch() << std::endl;
  std::cout << "| - version_fullhash: " << example_lib::version_fullhash() << std::endl;
  std::cout << "| - version_shorthash: " << example_lib::version_shorthash() << std::endl;
  std::cout << "| - version_isdirty: " << example_lib::version_isdirty() << std::endl;
  std::cout << "| - version_distance: " << example_lib::version_distance() << std::endl;
  std::cout << "| - version_flag: " << example_lib::version_flag() << std::endl;
}