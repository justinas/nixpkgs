{ stdenv, fetchFromGitHub, lib, autoPatchelfHook, libusb-compat-0_1 }:
let
  system = {
    "x86_64-linux" = "linux-x86";
  }.${stdenv.system};
in
stdenv.mkDerivation rec {
  pname = "aml-flash-tool";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "radxa";
    repo = "aml-flash-tool";
    rev = "v${version}";
    hash = "sha256-9hj9nOpx42zHA3J+tqPEmd6HCa/6skEsSuXsx3epI00=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ libusb-compat-0_1 ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib}
    cp aml-flash-tool.sh $out/bin
    cp --parents tools/${system}/* $out/lib

    runHook postInstall
  '';

  preFixup = ''
    sed -i "/^TOOL_PATH=/c\TOOL_PATH=$out/lib" $out/bin/aml-flash-tool.sh
  '';

  meta = with lib; {
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ justinas ];
  };
}
