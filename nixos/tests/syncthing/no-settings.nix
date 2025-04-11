{ lib, ... }:
{
  name = "syncthing-no-settings";
  meta.maintainers = with lib.maintainers; [
    chkno
    me-and
  ];

  containers = {
    a = {
      services.syncthing = {
        enable = true;
      };
    };
  };
  # Test that indeed a syncthing-init.service systemd service is not created.
  #
  testScript = # python
    ''
      a.wait_for_unit("syncthing.service")
      a.succeed("""
        if systemctl status syncthing-init.service; then
          !:
        else
          [ $? -eq 4 ]
        fi
      """)
    '';
}
