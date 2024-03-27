{ libdeltachat
, git
, python3Packages
}:
python3Packages.buildPythonPackage rec {
  pname = "deltachat-rpc-client";

  inherit (libdeltachat) version;
  src = libdeltachat.src.override {
    leaveDotGit = true;
    deepClone = true;
    rev = "refs/tags/v${libdeltachat.version}";
    hash = "sha256-UKZryj8oj2qsU/fCpFhQ48ZNQnvLjnL/FUuQyFj1hLA=";
  };
  sourceRoot = "${src.name}/deltachat-rpc-client";

  format = "pyproject";
  nativeBuildInputs = [
    python3Packages.setuptools
    python3Packages.setuptools-scm
    git
  ];

  meta = libdeltachat.meta // {
    description = "Delta Chat RPC client";
    mainProgram = "deltachat-rpc-server";
  };
}
