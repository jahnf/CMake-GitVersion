# CMake-GitVersion

(Yet another) automatic version generation for C++ CMake projects.

* Generates version information using information from git (tags) with fallback options
  when building without git (e.g. when building from sources with exported archives).
* Use custom templates for generated sources (e.g. also create resource files (see examples))
* Uses semantic versioning (https://semver.org/)
* Best suited with git-flow workflows
  * See: https://www.atlassian.com/de/git/tutorials/comparing-workflows/gitflow-workflow
  * See: https://nvie.com/posts/a-successful-git-branching-model/
* Generated version strings are compatible to/and can be used by debian and rpm packages.

## Version Generation

Defines
- `LAST_TAG_VERSION`: latest tagged version (e.g. 1.2.0 for tag v1.2.0) or 0.0.0 if no tag exists.
- `DIST`: commit count distance to latest version tag.

Version Number rules:
- on _master_:  `X.Y.Z`[-`DIST`] (using `LAST_TAG_VERSION`), while `DIST` should always be 0 on the master branch.
- on _develop_ and other branches: `X.Y.Z`-`ALPHA_FLAG`.`DIST` (using `LAST_TAG_VERSION`, `Y` incremented by 1)
- on release branches: `X.Y.Z`-`RC_FLAG`.`DIST` (extracting `X.Y.Z` from release branch name or from _develop_ as fallback). \
  `DIST` is either calculated to last version tag or to the closest `rc-X.Y.Z` tag.
- `DIST` is added to all version numbers, except:
  - Versions on _master_ and on _hotfix_ branches with `DIST` equal to 0
- All version numbers have a pre-release identifier set, except:
  - Version on _master_ and
  - versions on _hotfix_ branches with `DIST` equal to 0
- When creating the version string and the PATCH number is 0 - the patch number is omitted.
  (e.g. 1.2.0 will be 1.2)


## Examples

Have a look at [CMakeLists.txt](./CMakeLists.txt) and all fles in the `examples` directory.



