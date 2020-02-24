{pkgs ? import <nixpkgs> {} }:

with pkgs;
stdenv.mkDerivation rec {
  version = "0.13.54";
  name = "daml-sdk-${version}";
  src = fetchurl {
    url = "https://github.com/digital-asset/daml/releases/download/v${version}/daml-sdk-${version}-linux.tar.gz";
    sha256 = "1gyv7p1dp14dx5nmzzp5b54lhiny17wnwk1fgki3l7pxr4wgyksi";
  };
  buildInputs = [ pkgs.makeWrapper ];
  propagatedBuildInputs = [ pkgs.jdk ];

  installPhase = ''
    patchShebangs ./daml/
    patchShebangs ./.
    ./install.sh
    cp -R $HOME/.daml $out/
    wrapProgram $out/sdk/${version}/daml/daml --prefix PATH : ${pkgs.jdk}/bin
    ln -sf $out/sdk/${version}/daml/daml $out/bin/daml
  '';
}
