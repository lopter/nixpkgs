{ lib, buildGoModule, fetchFromGitHub, fetchurl, nix-update-script }:

buildGoModule rec {
  pname = "sops";
  version = "3.9.0";

  src = fetchFromGitHub {
    owner = "getsops";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-Q1e3iRIne9/bCLxKdhzP3vt3oxuHJAuG273HdeHZ3so=";
  };

  vendorHash = "sha256-3vzKQZTg38/UGVJ/M1jLALCgor7wztsLKVuMqY3adtI=";

  subPackages = [ "cmd/sops" ];

  ldflags = [ "-s" "-w" "-X github.com/getsops/sops/v3/version.Version=${version}" ];

  patches = [
    (fetchurl {
      url = "https://github.com/getsops/sops/commit/1b158865ef98313c17443a587ae438a7688d2e37.patch";
      sha256 = "sha256-F1DKQLC1e0y0qJv9KSj7UjApI6kjlvuji5kl2H7j660=";
    })
  ];

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    homepage = "https://getsops.io/";
    description = "Simple and flexible tool for managing secrets";
    changelog = "https://github.com/getsops/sops/blob/v${version}/CHANGELOG.rst";
    mainProgram = "sops";
    maintainers = with maintainers; [ Scrumplex mic92 ];
    license = licenses.mpl20;
  };
}
