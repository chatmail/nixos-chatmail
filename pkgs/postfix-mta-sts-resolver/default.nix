# Provides mta-sts-daemon application
{ lib
, python3
, fetchPypi
, python3Packages
, ...
}:
python3.pkgs.buildPythonApplication rec {
  pname = "postfix_mta_sts_resolver";
  version = "1.4.0";
  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-QUHDI5FShwc/YNAuomvBP8bf563Zu+LiP7nEtXbtGP0=";
  };

  propagatedBuildInputs = builtins.attrValues {
    inherit (python3Packages)
      setuptools

      pyyaml
      aiohttp
      aiodns
      aiosqlite
      asyncpg
      redis;
  };

  meta = {
    homepage = "https://github.com/Snawoot/postfix-mta-sts-resolver";
    description = "Daemon which provides TLS client policy for Postfix via socketmap, according to domain MTA-STS policy";
  };
}
