with (import <nixpkgs> {});
let
  env = bundlerEnv {
    name = "bundler-env";
    gemdir  = ./nix/gem;

    gemConfig = defaultGemConfig // {
      # HashDiff presently has an intrusive unconditional deprecation message.
      # We use it correctly, we don't need to see the message.
      hashdiff = attrs: {
        patches = [
          (fetchpatch {
            url = "https://github.com/liufengyun/hashdiff/commit/2dc6adc71739c4aec23c1a946e25ea36f8c69f58.diff";
            sha256="1pibvad2fxpg30pjdhk2q8ly4pfn7yiyv331zdvw9viqickx225j"; })
        ];
        dontBuild = false;
      };
    };
  };
in stdenv.mkDerivation {
  name = "shell";
  buildInputs = [ env ];
}
