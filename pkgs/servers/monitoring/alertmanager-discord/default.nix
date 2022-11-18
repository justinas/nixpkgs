{ buildGoModule, fetchFromGitHub, lib }:
buildGoModule {
  pname = "alertmanager-discord";
  version = "unstable-2022-08-12";

  src = fetchFromGitHub {
    owner = "benjojo";
    repo = "alertmanager-discord";
    rev = "89ef841a7ef43c5520df49d0c28335d899230eb9";
    hash = "sha256-6P90c3ECUtmXxr2b0/yVscSI/bBgpXkrhou7Cne/bEM=";
  };
  vendorSha256 = null;

  meta = with lib; {
    description = "Alert manager webhook receiver that posts alerts to Discord";
    homepage = "https://github.com/benjojo/alertmanager-discord";
    license = licenses.asl20;
    maintainers = with maintainers; [ justinas ];
    platforms = platforms.all;
  };
}
