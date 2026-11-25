# shellcheck shell=bash
# Sourced by the cmake-binary scripts: the platform an archive is built for.
#   platform_os    macos or linux (else the kernel name, lower case)
#   platform_arch  arm64 or x86_64 (else the machine name)
platform_os() {
  case $(uname -s) in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    *) uname -s | tr '[:upper:]' '[:lower:]' ;;
  esac
}
platform_arch() {
  case $(uname -m) in
    arm64 | aarch64) echo arm64 ;;
    x86_64 | amd64) echo x86_64 ;;
    *) uname -m ;;
  esac
}
