_final: prev: rec {
  deltachat-rpc-server = prev.callPackage ./pkgs/deltachat-rpc-server { };
  deltachat-rpc-client = prev.callPackage ./pkgs/deltachat-rpc-client { };
  chatmaild = prev.callPackage ./pkgs/chatmaild { };
  postfix-mta-sts-resolver = prev.callPackage ./pkgs/postfix-mta-sts-resolver { };
  opendkim = prev.opendkim.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ [ "--with-lua=${prev.lua}" ];
  });
  dovecot = prev.dovecot.overrideAttrs (_finalAttrs: previousAttrs: {
    patches = previousAttrs.patches ++ [ ./dovecot-storage-remove-500-ms-debounce.patch ];
  });
}
