{ deltachat-rpc-client, deltachat-rpc-server, python3Packages, fetchFromGitHub, ... }:
let
  buildPythonPackage = python3Packages.buildPythonPackage;
  src = fetchFromGitHub {
    owner = "deltachat";
    repo = "chatmail";
    rev = "9fdf4fd2afd93cfdb71785fa20e092bad67b8277";
    sha256 = "sha256-hIM9xFsbdHDjZz5Y8ON+ZQzIczvozRR7D+iYhMrZLU4=";
  };
in
buildPythonPackage {
  name = "chatmaild";
  inherit src;
  version = "0-unstable-2024-03-03";
  sourceRoot = "${src.name}/chatmaild";
  format = "pyproject";
  propagatedBuildInputs = [
    python3Packages.setuptools
    python3Packages.aiosmtpd
    python3Packages.iniconfig
    python3Packages.requests
    deltachat-rpc-server
    deltachat-rpc-client
  ];
}
