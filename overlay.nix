final: prev: {
  chatmaild = prev.callPackage ./pkgs/chatmaild
    {
      pkgs = prev;
    };
}
