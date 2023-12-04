with (import <nixpkgs> {});
let
  ruby = ruby_3_1;
  env = bundlerEnv {
    inherit ruby;
    name = "bundler-env";
    gemdir  = ./nix/gem;
  };
in stdenv.mkDerivation {
  name = "shell";
  buildInputs = [ env ruby ];
}
