{ lib
, stdenv
, cmake
, curl
, fetchFromGitHub
, hunspell
, pkg-config
, qmake
, qtbase
, qtwebengine
, wrapGAppsHook
, wrapQtAppsHook
}:
let
  version = "2.0.0";
  srcs = {
    mindforger = fetchFromGitHub {
      owner = "dvorka";
      repo = "mindforger";
      rev = version;
      sha256 = "sha256-+8miV2xuQcaWGdWCEXPIg6EXjAHtgD9pX7Z8ZNhpMjA=";
    };
    cmark-gfm = fetchFromGitHub {
      owner = "dvorka";
      repo = "cmark";
      rev = "4ca8688093228c599432a87d7bd945804c573d51";
      sha256 = "sha256-0WiG8aot8mc0h1BKPgC924UKQrgunZvKKBy9bD7nhoQ=";
    };
  };
in stdenv.mkDerivation {
  pname = "mindforger";
  inherit version;

  src = srcs.mindforger;

  nativeBuildInputs = [ cmake pkg-config qmake wrapGAppsHook wrapQtAppsHook ];
  buildInputs = [ curl hunspell qtbase qtwebengine ];

  # Disable the cmake hook (so we don't try to build MindForger with it), and
  # build MindForger's internal fork of cmark-gfm ahead of MindForger itself:
  postUnpack = "cp -TR ${srcs.cmark-gfm} $sourceRoot/deps/cmark-gfm";
  dontUseCmakeConfigure = true;
  preBuild = ''(
      mkdir deps/cmark-gfm/build &&
      cd deps/cmark-gfm/build &&
      cmake -DCMARK_TESTS=OFF -DCMARK_SHARED=OFF .. &&
      cmake --build . --parallel
  )'';

  doCheck = true;

  patches = [
    ./hunspell_pkgconfig.patch
  ];

  postPatch = ''
    substituteInPlace lib/src/install/installer.cpp --replace /usr "$out"
    substituteInPlace app/resources/gnome-shell/mindforger.desktop --replace /usr "$out"
    for f in app/app.pro lib/lib.pro; do
      substituteInPlace "$f" --replace "QMAKE_CXX = g++" ""
    done
  '';

  qmakeFlags = [
    "-r"
    "mindforger.pro"
    "CONFIG+=mfnoccache"
    "CONFIG+=mfwebengine"
  ];

  postInstall = lib.optionalString stdenv.isDarwin ''
    mkdir "$out"/Applications
    mv app/mindforger.app "$out"/Applications/
  '';

  meta = with lib; {
    description = "Thinking Notebook & Markdown IDE";
    longDescription = ''
     MindForger is actually more than an editor or IDE - it's human
     mind inspired personal knowledge management tool
    '';
    homepage = "https://www.mindforger.com";
    license = licenses.gpl2Plus;
    platforms = platforms.all;
    maintainers = with maintainers; [ cyplo ];
    mainProgram = "mindforger";
  };
}
