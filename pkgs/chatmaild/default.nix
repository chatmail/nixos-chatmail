{ buildPythonPackage
, fetchFromGitHub
, python3Packages
}:
buildPythonPackage rec {
  name = "chatmaild";
  version = "0-unstable-2024-03-03";
  src = fetchFromGitHub {
    owner = "deltachat";
    repo = "chatmail";
    rev = "14342383cf6294241e49576b404a4606c11c8e34";
    sha256 = "sha256-ceC7J+qEyxsdUKrfb+/D6wz6g+Yw7tYH+KrLJdOZEVw=";
  };
  sourceRoot = "${src.name}/chatmaild";
  format = "pyproject";
  propagatedBuildInputs = [
    python3Packages.setuptools
    python3Packages.aiosmtpd
    python3Packages.iniconfig
    python3Packages.requests
    # Also deltachat-rpc-client and deltachat-rpc-server for echobot
  ];
}
