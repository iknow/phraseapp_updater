with (import <nixpkgs> {});
let
  env = bundlerEnv {
    name = "bundler-env";
    gemdir  = ./nix/gem;
  };
in stdenv.mkDerivation {
  name = "shell";
  buildInputs = [ env ];
}
