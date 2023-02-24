with (import <nixpkgs> {});
let
  env = bundlerEnv {
    ruby = ruby_3_0;
    name = "bundler-env";
    gemdir  = ./nix/gem;
  };
in stdenv.mkDerivation {
  name = "shell";
  buildInputs = [ env ];
}
