{ stdenv, lib, fetchurl, iptables-legacy, libmnl, libnftnl, libuuid, openssl, pkg-config
, which, iproute2, nftables, gnused, coreutils, gawk, makeWrapper
, nixosTests
, useNftables ? false
}:

let
  scriptBinEnv = lib.makeBinPath ([ which iproute2 gnused coreutils gawk ] ++
    (if useNftables then [ nftables ] else [ iptables-legacy ]));
in
stdenv.mkDerivation rec {
  pname = "miniupnpd";
  version = "2.3.3";

  src = fetchurl {
    url = "https://miniupnp.tuxfamily.org/files/miniupnpd-${version}.tar.gz";
    sha256 = "sha256-b9cBn5Nv+IxB58gi9G8QtRvXLWZZePZYZIPedbMMNr8=";
  };

  buildInputs = [ iptables-legacy libuuid openssl ]
    ++ (lib.optionals useNftables [ libmnl libnftnl ]);
  nativeBuildInputs= [ pkg-config makeWrapper ];

  # ./configure is not a standard configure file, errors with:
  # Option not recognized : --prefix=
  dontAddPrefix = true;

  configureFlags = lib.optional useNftables "--firewall=nftables";
  installFlags = [ "PREFIX=$(out)" "INSTALLPREFIX=$(out)" ];

  postFixup = ''
    scripts=$(echo ${if useNftables
    then ''$out/etc/miniupnpd/nft_{delete_chain,flush,init,removeall}.sh''
    else ''$out/etc/miniupnpd/ip{,6}tables_{init,removeall}.sh''})
    for script in $scripts
    do
      wrapProgram $script --set PATH '${scriptBinEnv}:$PATH'
    done
  '';

  passthru.tests = {
    bittorrent-integration = nixosTests.bittorrent;
    inherit (nixosTests) upnp;
  };

  meta = with lib; {
    homepage = "https://miniupnp.tuxfamily.org/";
    description = "A daemon that implements the UPnP Internet Gateway Device (IGD) specification";
    platforms = platforms.linux;
    license = licenses.bsd3;
  };
}
