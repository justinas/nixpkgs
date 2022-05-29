{ fetchFromGitHub
, lib
, python3
, qtbase
, wrapQtAppsHook

, withGtk ? true
, withQt ? true
}:

python3.pkgs.buildPythonApplication rec {
  pname = "trackma";
  version = "0.8.4";
  src = fetchFromGitHub {
    owner = "z411";
    repo = "trackma";
    rev = "v${version}";
    sha256 = "1ir00sgjxd057nhdha6isx0a94q7qagcpadxzi880ngqh3s3gdvn";
  };

  nativeBuildInputs = [ wrapQtAppsHook ];

  buildInputs = [ ]
    ++ lib.optionals withQt [ qtbase ];

  propagatedBuildInputs = with python3.pkgs; [ pillow pydbus pyinotify urwid ]
    ++ lib.optionals withQt [ pyqt5 ];

  postInstall = ''
    wrapQtApp $out/bin/trackma-qt
    rm $out/bin/trackma-gtk # Not packaged yet
  '';

  doCheck = false; # tests included in next version
}
