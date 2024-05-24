{ stdenv
, lib
, fetchFromGitHub
, copyDesktopItems
, makeDesktopItem
, qt6
}:
stdenv.mkDerivation rec {
  pname = "openterface-qt";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "TechxArtisanStudio";
    repo = "Openterface_QT";
    rev = "v${version}";
    hash = "sha256-yLY8C0PUoVlDtusVISUWhUcRRpGj6E+YrOyS54Udnzk=";
  };

  buildInputs = with qt6; [
    qtbase
    qtmultimedia
    qtserialport
  ];
  nativeBuildInputs = with qt6; [ copyDesktopItems qmake wrapQtAppsHook ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/pixmaps}
    mv openterfaceQT $out/bin
    cp images/icon_128.png  $out/share/pixmaps/openterface-qt.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "Openterface-QT";
      desktopName = "Openterface QT";
      comment = meta.description;
      categories = [ "Utility" ];
      exec = "openterfaceQT";
      icon = "openterface-qt";
    })
  ];

  meta = with lib; {
    description = "Qt-based client for Openterface Mini-KVM";
    homepage = "https://openterface.com/";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ justinas ];
    platforms = platforms.linux;
  };
}
