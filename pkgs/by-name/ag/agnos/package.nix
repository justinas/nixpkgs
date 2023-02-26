{ fetchFromGitHub
, lib
, nixosTests
, rustPlatform
, stdenv
, darwin
, openssl
, pkg-config
}:
rustPlatform.buildRustPackage {
  pname = "agnos";
  version = "unstable-2024-04-19";

  src = fetchFromGitHub {
    owner = "krtab";
    repo = "agnos";
    rev = "9b350069dc5329b4d8a2dbc4a3e8533bb2266909";
    hash = "sha256-IfZNQvD6enURSnR8OODnsDiQ6Q8bPnwzoVSlqkOHWW8=";
  };

  cargoHash = "sha256-pFz1xY9WXVSiDXKVoUwts6LCHNeZbbWMR7PiRGLk6lo=";

  buildInputs = [ openssl ] ++
    lib.optional stdenv.isDarwin darwin.apple_sdk.frameworks.Security;
  nativeBuildInputs = [ pkg-config ];

  meta = with lib; {
    description = "Obtains certificates from Let's Encrypt using DNS-01 without the need for API access to the DNS provider";
    homepage = "https://github.com/krtab/agnos";
    license = licenses.mit;
    maintainers = with maintainers; [ justinas ];
  };

  passthru.tests = nixosTests.agnos;
}
