final: prev: {
  chatmaild = prev.callPackage ./pkgs/chatmaild
    {
      buildPythonPackage = prev.python3Packages.buildPythonPackage;
      fetchFromGitHub = prev.fetchFromGitHub;
      python3Packages = prev.python3Packages;
    };
}
