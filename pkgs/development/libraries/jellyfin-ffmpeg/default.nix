{ ffmpeg_5, ffmpeg-full, fetchFromGitHub, lib }:

(ffmpeg-full.override { ffmpeg = ffmpeg_5; }).overrideAttrs (old: rec {
  pname = "jellyfin-ffmpeg";
  version = "5.0.1-2";

  src = fetchFromGitHub {
    owner = "jellyfin";
    repo = "jellyfin-ffmpeg";
    rev = "v${version}";
    sha256 = "0hdi44jq22gafrc2m6xylq4412a2p27cfhvfy18ddg69dcs4anjz";
  };

  postPatch = ''
    for file in $(cat debian/patches/series); do
      patch -p1 < debian/patches/$file
    done

    ${old.postPatch or ""}
  '';

  meta = with lib; {
    description = "${old.meta.description} (Jellyfin fork)";
    homepage = "https://github.com/jellyfin/jellyfin-ffmpeg";
    license = licenses.gpl3;
    maintainers = with maintainers; [ justinas ];
  };
})
