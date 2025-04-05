import ./make-test-python.nix (
  { pkgs, ... }:
  let

    testId = "7CFNTQM-IMTJBHJ-3UWRDIU-ZGQJFR6-VCXZ3NB-XUH3KZO-N52ITXR-LAIYUAU";
    apiKey = "very_secret_key";
  in
  {
    name = "syncthing-init";
    meta.maintainers = with pkgs.lib.maintainers; [ lassulus ];

    nodes.machine = {
      environment.systemPackages = [ pkgs.curl ];
      services.syncthing = {
        enable = true;
        settings.devices.testDevice = {
          id = testId;
        };
        settings.folders.testFolder = {
          path = "/tmp/test";
          devices = [ "testDevice" ];
        };
        settings.gui.user = "guiUser";
        settings.gui.apikey = apiKey;
      };
    };

    testScript = ''
      machine.wait_for_unit("syncthing-init.service")
      config = machine.succeed("cat /var/lib/syncthing/.config/syncthing/config.xml")

      assert "testFolder" in config
      assert "${testId}" in config
      assert "guiUser" in config

      # Create a folder with a / in its id, since we have overrideFolders true
      # it should get deleted when we restart syncthing-init.service
      machine.succeed("""
          curl -sSf -H 'X-API-Key: ${apiKey}' \
            -d '{"autoNormalize":false,"caseSensitiveFS":true,"copyOwnershipFromParent":false,"devices":[],"enable":true,"id":"sync/thing","label":"Sync/thing directory","path":"/tmp/syncthing","type":"sendreceive","versioning":null}' \
            127.0.0.1:8384/rest/config/folders
      """)
      machine.wait_until_succeeds("grep -q 'sync/thing' /var/lib/syncthing/.config/syncthing/config.xml", timeout=5)

      machine.systemctl("restart syncthing-init.service")
      machine.wait_for_unit("syncthing-init.service")
      config = machine.succeed("cat /var/lib/syncthing/.config/syncthing/config.xml")
      assert "sync/thing" not in config, "sync/thing folder should have been deleted by syncthing-init"
    '';
  }
)
