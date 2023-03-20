{ lib, stdenv, fetchurl, autoPatchelfHook, mongodb }:
stdenv.mkDerivation rec {
  pname = "omada-controller";
  version = "5.9.9";
  src = fetchurl {
    url = "https://static.tp-link.com/upload/software/2023/202302/20230227/Omada_SDN_Controller_v${version}_Linux_x64.tar.gz";
    hash = "sha256-IXAICkFL4gI5T5mUBjB9oSPSRI4xjYKe9UrIoSaW010=";
  };

  buildInputs = [ autoPatchelfHook stdenv.cc.cc ];

  buildPhase = ''
    runHook preBuild

    mkdir -p $out
    cp -r bin lib properties $out

    ln -s ${mongodb}/bin/mongod $out/bin

    runHook postBuild
  '';

  meta = with lib; {
    description = "TP-Link Omada software controller";
    homepage = "https://www.tp-link.com/us/support/download/omada-software-controller/";
    license = licenses.unfree;
    maintainers = with maintainers; [ justinas ];
  };
}
