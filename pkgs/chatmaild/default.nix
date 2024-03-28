{ deltachat-rpc-client, deltachat-rpc-server, python3Packages, fetchFromGitHub, ... }:
let
  buildPythonPackage = python3Packages.buildPythonPackage;
  src = fetchFromGitHub {
    owner = "deltachat";
    repo = "chatmail";
    rev = "1.1.0";
    sha256 = "sha256-8mPEprtVGEWN6rUveEqasf4PuiWDas+/j3KQAUvjLGo=";
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
    python3Packages.filelock
    deltachat-rpc-server
    deltachat-rpc-client
  ];
}
