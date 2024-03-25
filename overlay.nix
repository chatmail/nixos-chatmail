final: prev: {
  chatmaild = prev.callPackage ./pkgs/chatmaild prev;
  postfix-mta-sts-resolver = prev.callPackage ./pkgs/postfix-mta-sts-resolver prev;
  opendkim = prev.opendkim.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ [ "--with-lua=${prev.lua}" ];
  });
}
