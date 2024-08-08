{
  lib,
  rustPlatform,
  fetchFromGitHub,
  substituteAll,
  nix-update-script,
  pkg-config,
  autoAddDriverRunpath,
  alsa-lib,
  brotli,
  bzip2,
  ffmpeg,
  jack2,
  lame,
  libX11,
  libXi,
  libXrandr,
  libXcursor,
  libdrm,
  libglvnd,
  libogg,
  libpng,
  libtheora,
  libunwind,
  libva,
  libvdpau,
  libxkbcommon,
  openssl,
  openvr,
  pipewire,
  rust-cbindgen,
  soxr,
  vulkan-headers,
  vulkan-loader,
  wayland,
  x264,
  xvidcore,
}:

rustPlatform.buildRustPackage rec {
  pname = "alvr";
  version = "20.9.1";

  src = fetchFromGitHub {
    owner = "alvr-org";
    repo = "ALVR";
    rev = "refs/tags/v${version}";
    fetchSubmodules = true; #TODO devendor openvr
    hash = "sha256-MthBwLC1sInlt3b9X9drxcga8+6vnBa5PqlmMtyzfi0=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "openxr-0.17.1" = "sha256-fG/JEqQQwKP5aerANAt5OeYYDZxcvUKCCaVdWRqHBPU=";
      "settings-schema-0.2.0" = "sha256-luEdAKDTq76dMeo5kA+QDTHpRMFUg3n0qvyQ7DkId0k=";
    };
  };

  patches = [
    (substituteAll {
      src = ./fix-finding-libs.patch;
      ffmpeg = lib.getDev ffmpeg;
      x264 = lib.getDev x264;
    })
  ];

  env = {
    NIX_CFLAGS_COMPILE = toString [
      "-lbrotlicommon"
      "-lbrotlidec"
      "-lcrypto"
      "-lpng"
      "-lssl"
    ];
  };

  RUSTFLAGS = map (a: "-C link-arg=${a}") [
      "-Wl,--push-state,--no-as-needed"
      "-lEGL"
      "-lwayland-client"
      "-lxkbcommon"
      "-Wl,--pop-state"
  ];

  nativeBuildInputs = [
    rust-cbindgen
    pkg-config
    rustPlatform.bindgenHook
    autoAddDriverRunpath
  ];

  buildInputs = [
    alsa-lib
    brotli
    bzip2
    ffmpeg
    jack2
    lame
    libX11
    libXcursor
    libXi
    libXrandr
    libdrm
    libglvnd
    libogg
    libpng
    libtheora
    libunwind
    libva
    libvdpau
    libxkbcommon
    openssl
    openvr
    pipewire
    soxr
    vulkan-headers
    vulkan-loader
    wayland
    x264
    xvidcore
  ];

  doCheck = false; # TODO: remove
  buildPhase = ''
    runHook preBuild

    cargo xtask build-streamer --release

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 ${src}/alvr/xtask/resources/alvr.desktop $out/share/applications/alvr.desktop
    install -Dm644 ${src}/resources/alvr.png $out/share/icons/hicolor/256x256/apps/alvr.png

    # Install SteamVR driver
    mkdir -p $out/{bin,libexec,lib/alvr,share}
    cp -r ./build/alvr_streamer_linux/bin/. $out/bin
    cp -r ./build/alvr_streamer_linux/lib64/. $out/lib
    cp -r ./build/alvr_streamer_linux/libexec/. $out/libexec
    cp -r ./build/alvr_streamer_linux/share/. $out/share
    ln -s $out/lib $out/lib64

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Stream VR games from your PC to your headset via Wi-Fi";
    homepage = "https://github.com/alvr-org/ALVR/";
    changelog = "https://github.com/alvr-org/ALVR/releases/tag/v${version}";
    license = licenses.mit;
    mainProgram = "alvr_dashboard";
    maintainers = with maintainers; [ passivelemon ];
    platforms = platforms.linux;
  };
}
