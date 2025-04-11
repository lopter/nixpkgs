{ lib, pkgs, ... }:
{
  name = "syncthing";
  meta.maintainers = with pkgs.lib.maintainers; [ chkno ];

  nodes = {
    a = {
      environment.systemPackages = with pkgs; [
        curl
        libxml2
        syncthing
      ];
      services.syncthing = {
        enable = true;
      };
    };
  };
  # Test that indeed a syncthing-init.service systemd service is not created.
  #
  testScript = # python
    ''
      a.succeed("""
        if systemctl status syncthing-init.service; then
          !:
        else
          [ $? -eq 4 ]
        fi
      """)
    '';
}
