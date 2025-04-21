{ lib, bundlerApp, ruby, defaultGemConfig, makeWrapper, fetchpatch, git }:

bundlerApp rec {
  pname = "phraseapp_updater";
  exes = ["phraseapp_updater"];

  inherit ruby;

  gemdir = ./gem;

  nativeBuildInputs = [makeWrapper];

  postBuild = ''
    wrapProgram $out/bin/phraseapp_updater --prefix PATH : ${lib.makeBinPath [ ruby ]}
  '';

  gemConfig = defaultGemConfig // {
    phraseapp_updater = attrs: {
      src = ../.;
      dontBuild = false;
      nativeBuildInputs = [ git ];
    };
  };

  meta = with lib; {
    description = "A tool for merging data on PhraseApp with local changes (usually two git revisions)";
    homepage = https://github.com/iknow/phraseapp_updater;
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
