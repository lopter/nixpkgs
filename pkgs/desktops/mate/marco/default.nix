{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  gettext,
  itstool,
  libxml2,
  libcanberra-gtk3,
  libgtop,
  libXdamage,
  libXpresent,
  libXres,
  libstartup_notification,
  zenity,
  glib,
  gtk3,
  mate-desktop,
  mate-settings-daemon,
  wrapGAppsHook3,
  mateUpdateScript,
}:

stdenv.mkDerivation rec {
  pname = "marco";
  version = "1.28.1";

  src = fetchurl {
    url = "https://pub.mate-desktop.org/releases/${lib.versions.majorMinor version}/${pname}-${version}.tar.xz";
    sha256 = "JJbl5A7pgM1oSUk6w+D4/Q3si4HGdNqNm6GaV38KwuE=";
  };

  nativeBuildInputs = [
    pkg-config
    gettext
    itstool
    libxml2 # xmllint
    wrapGAppsHook3
  ];

  buildInputs = [
    libcanberra-gtk3
    libgtop
    libXdamage
    libXpresent
    libXres
    libstartup_notification
    gtk3
    zenity
    mate-desktop
    mate-settings-daemon
  ];

  postPatch = ''
    substituteInPlace src/core/util.c \
      --replace-fail 'argvl[i++] = "zenity"' 'argvl[i++] = "${lib.getExe zenity}"'
  '';

  env.NIX_CFLAGS_COMPILE = "-I${glib.dev}/include/gio-unix-2.0";
  env.ZENITY = lib.getExe zenity;

  enableParallelBuilding = true;

  passthru.updateScript = mateUpdateScript { inherit pname; };

  meta = with lib; {
    description = "MATE default window manager";
    homepage = "https://github.com/mate-desktop/marco";
    license = [ licenses.gpl2Plus ];
    platforms = platforms.unix;
    teams = [ teams.mate ];
  };
}
