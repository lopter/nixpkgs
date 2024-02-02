{ lib
, buildPythonPackage
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

buildPythonPackage ({
  pname = "buildbot_worker";
  inherit (buildbot) src version;

  patches = [
    ./buildbot_worker_no_pythonpath_merging.patch
  ];

  postPatch = ''
    cd worker
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
  ] ++ twisted.optional-dependencies.tls;

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
