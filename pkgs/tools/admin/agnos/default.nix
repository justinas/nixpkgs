{ fetchFromGitHub
, lib
, nixosTests
, rustPlatform
, stdenv

, openssl
, pkg-config

, Security
}:
rustPlatform.buildRustPackage rec {
  pname = "agnos";
  version = "0.1.0-beta.3";

  src = fetchFromGitHub {
    owner = "krtab";
    repo = "agnos";
    rev = "v${version}";
    hash = "sha256-Lbnd2JjxbRss+ormyxOw0hdljsdACFjNawsl+jwgTao=";
  };

  cargoHash = "sha256-++51dkoVjj9jc0cepDRk+ye8FLy8sul33zfYxA/WEE4=";

  buildInputs = [ openssl ] ++ (lib.optionals stdenv.isDarwin [ Security ]);
  nativeBuildInputs = [ pkg-config ];

  meta = with lib; {
    description = "Obtains certificates from Let's Encrypt using DNS-01 without the need for API access to the DNS provider";
    homepage = "https://github.com/krtab/agnos";
    license = licenses.mit;
    maintainers = with maintainers; [ justinas ];
  };
}
