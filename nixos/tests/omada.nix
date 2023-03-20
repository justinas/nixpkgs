{ system ? builtins.currentSystem
, config ? { allowUnfree = true; }
, pkgs ? import ../.. { inherit system config; }
, lib ? pkgs.lib
}:

with import ../lib/testing-python.nix { inherit system pkgs; };
makeTest {
  name = "omada";
  meta.maintainers = with lib.maintainers; [ justinas ];

  nodes.server = {
    nixpkgs.config = config;

    services.omada = {
      enable = true;
    };
  };

  testScript = ''
    server.wait_for_unit("omada.service")
    server.wait_until_succeeds("curl -sSLk https://localhost:8043", timeout=300)
  '';
}
