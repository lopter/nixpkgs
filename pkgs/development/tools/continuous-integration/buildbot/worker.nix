{ lib
, buildPythonPackage
, fetchPypi
, buildbot
, stdenv

# patch
, coreutils

# propagates
, autobahn
, future
, msgpack
, twisted

# tests
, parameterized
, psutil
, setuptools-trial

# passthru
, nixosTests
}:

buildPythonPackage (rec {
  pname = "buildbot_worker";
  inherit (buildbot) version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-7DAo1Yy20FeWXawV4wHzXDGtgyIGDJQuD2joJma96rM=";
  };

  patches = [
    (builtins.fetchurl {
      url = "https://www.kalessin.fr/~kal/buildbot_worker_no_pythonpath_merging_1.patch";
      sha256 = "10dhbcjqrjh6lix9hvi194pgraxx3js62004wmzxji4048l752w2";
    })
  ];

  postPatch = ''
    substituteInPlace buildbot_worker/scripts/logwatcher.py \
      --replace /usr/bin/tail "${coreutils}/bin/tail"
  '';

  nativeBuildInputs = [
    setuptools-trial
  ];

  propagatedBuildInputs = [
    autobahn
    future
    msgpack
    twisted
  ];

  nativeCheckInputs = [
    parameterized
    psutil
  ];

  passthru.tests = {
    smoke-test = nixosTests.buildbot;
  };

  meta = with lib; {
    homepage = "https://buildbot.net/";
    description = "Buildbot Worker Daemon";
    maintainers = teams.buildbot.members;
    license = licenses.gpl2;
    broken = stdenv.isDarwin; # https://hydra.nixos.org/build/243534318/nixlog/6
  };
})
