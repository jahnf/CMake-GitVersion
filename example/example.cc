#include <iostream>

#include <example-GitVersion.h>

int main(int argc, char** argv)
{
  std::cout << "CMake-GitVersion example"<< std::endl;
  std::cout << "- version_string: " << example::version_string() << std::endl;
  std::cout << "- version_branch: " << example::version_branch() << std::endl;
  std::cout << "- version_fullhash: " << example::version_fullhash() << std::endl;
  std::cout << "- version_shorthash: " << example::version_shorthash() << std::endl;
  std::cout << "- version_isdirty: " << example::version_isdirty() << std::endl;
  std::cout << "- version_distance: " << example::version_distance() << std::endl;
  std::cout << "- version_flag: " << example::version_flag() << std::endl;
  return 0;
}