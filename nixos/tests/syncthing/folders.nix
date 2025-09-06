{ lib, pkgs, ... }:
let
  nodeNames = [
    "a"
    "b"
    "c"
  ];
  nodeDirs = lib.genAttrs nodeNames (n: ./test-nodes + "/${n}");
  nodeData = lib.mapAttrs (n: v: {
    cert = "${v}/cert.pem";
    key = "${v}/key.pem";
    id = lib.fileContents (v + "/id");
  }) nodeDirs;

  testPassword = "it's a secret";

  stCurlFor =
    guiAddress:
    let
      addressArgs =
        if lib.strings.hasPrefix "unix://" guiAddress then
          # curl still needs a hostname to build the Host header, even though
          # the connection itself goes through the socket.
          "--unix-socket ${lib.strings.removePrefix "unix://" guiAddress} http://syncthing.local"
        else
          "http://${guiAddress}";
    in
    pkgs.writeShellApplication {
      name = "st-curl";
      runtimeInputs = [ pkgs.curl ];
      # Takes the REST API path as its first argument, any further arguments
      # are passed through to curl.
      text = ''
        path="$1"
        shift
        exec curl -sSLk -H ${lib.escapeShellArg "X-API-Key: ${testPassword}"} \
          --retry 1000 --retry-delay 1 --retry-all-errors \
          ${addressArgs}"$path" "$@"
      '';
    };

  commonNodeConfigModule = {
    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      overrideFolders = false;
      settings.devices = lib.mapAttrs (n: v: { inherit (v) id; }) nodeData;
    };
  };

  nodeConfigModules = {
    a = {
      services.syncthing = {
        inherit (nodeData.a) cert key;
        overrideDevices = false;
        guiAddress = "unix:///run/syncthing/syncthing.sock";
      };
    };
    b = {
      services.syncthing = { inherit (nodeData.b) cert key; };
    };
    c = {
      services.syncthing = { inherit (nodeData.c) cert key; };
    };
  };

  nodeFolderConfigModules = [
    # "foo" is a folder that is synchronised only between nodes a and b.
    (
      let
        abFooConfig = {
          services.syncthing.settings.folders.foo = {
            path = "/var/lib/syncthing/foo";
            devices = [
              "a"
              "b"
            ];
          };
        };
      in
      {
        a = abFooConfig;
        b = abFooConfig;
        c = { };
      }
    )

    # "bar" is synchronised between a and c, and between b and c, but c only
    # gets an encrypted copy, and a and b never synchronise directly to each
    # other.
    (
      let
        abBarConfig =
          { config, ... }:
          {
            environment.etc.bar-encryption-password.text = testPassword;
            environment.etc.gui-api-key.text = testPassword;

            environment.systemPackages = [
              (stCurlFor config.services.syncthing.guiAddress)
              pkgs.jq
            ];

            services.syncthing.apiKeyFile = "/etc/${config.environment.etc.gui-api-key.target}";

            services.syncthing.settings.folders.bar = {
              path = "/var/lib/syncthing/bar";
              devices = [
                {
                  name = "c";
                  encryptionPasswordFile = "/etc/${config.environment.etc.bar-encryption-password.target}";
                }
              ];
            };
          };
      in
      {
        a = abBarConfig;
        b = abBarConfig;
        c = {
          services.syncthing.settings.folders.bar = {
            path = "/var/lib/syncthing/bar";
            devices = [
              "a"
              "b"
            ];
            type = "receiveencrypted";
          };
        };
      }
    )

    # "baz" is synchronised between all three nodes, but has filters on b and c
    # that mean they shouldn't receive certain files.
    {
      a = {
        services.syncthing.settings.folders.baz = {
          path = "/var/lib/syncthing/baz";
          devices = [
            "b"
            "c"
          ];
          ignorePatterns = [ ];
        };
      };

      b = {
        services.syncthing.settings.folders.baz = {
          path = "/var/lib/syncthing/baz";
          devices = [
            "a"
            "c"
          ];
          ignorePatterns = [
            "notB"
            # Just test that an apostrophe doesn't break the curl config
            # commands.  See: https://github.com/NixOS/nixpkgs/issues/554744
            "apostrophe'"
          ];
        };
      };

      c = {
        services.syncthing.settings.folders.baz = {
          path = "/var/lib/syncthing/baz";
          devices = [
            "a"
            "b"
          ];
          ignorePatterns = [ "notC" ];
        };
      };
    }

    # "foo bar" tests handling whitespace in folder IDs.
    {
      a = {
        services.syncthing.settings.folders."foo bar" = {
          path = "/var/lib/syncthing/foo-bar";
          devices = [ "b" ];
        };
      };

      b = {
        services.syncthing.settings.folders."foo bar" = {
          path = "/var/lib/syncthing/foo-bar";
          devices = [ "a" ];
          ignorePatterns = [ "notB" ];
        };
      };

      c = { };
    }
  ];
in
{
  name = "syncthing-folders";
  meta.maintainers = with lib.maintainers; [
    zarelit
    me-and
  ];

  # Run from the root of the nixpkgs repository with
  #
  #     nix-build -A nixosTests.syncthing-folders.genNodeData &&
  #       ./result/bin/genNodeData.sh
  #
  # This generates new keys, certificates, and overall Syncthing config, and
  # updates the certificate and key files and the ID file extracted from the
  # overall Syncthing config file.
  passthru.genNodeData = pkgs.writeShellApplication {
    name = "genNodeData.sh";
    runtimeInputs = with pkgs; [
      syncthing
      libxml2
    ];
    text = ''
      rm -r nixos/tests/syncthing/test-nodes
      mkdir nixos/tests/syncthing/test-nodes
      cd nixos/tests/syncthing/test-nodes

      for d in ${lib.escapeShellArgs nodeNames}; do
        mkdir -- "$d"
        syncthing generate --home="$d"
        xmllint --xpath 'string(configuration/device/@id)' "$d"/config.xml >"$d"/id
        rm -f -- "$d"/.syncthing.tmp.* "$d"/config.xml
      done
    '';
  };

  containers = lib.genAttrs nodeNames (n: {
    imports = [
      commonNodeConfigModule
      nodeConfigModules."${n}"
    ]
    ++ map (builtins.getAttr n) nodeFolderConfigModules;
  });

  testScript = # python
    ''
      import functools
      import json
      import shlex

      start_all()

      for n in (a, b, c):
        n.wait_for_unit("syncthing.service")
        n.wait_for_open_port(22000)

      # Test foo

      a.wait_for_file("/var/lib/syncthing/foo")
      b.wait_for_file("/var/lib/syncthing/foo")

      a.succeed("echo a2b > /var/lib/syncthing/foo/a2b")
      b.succeed("echo b2a > /var/lib/syncthing/foo/b2a")

      a.wait_for_file("/var/lib/syncthing/foo/b2a")
      b.wait_for_file("/var/lib/syncthing/foo/a2b")

      # Test bar

      a.wait_for_file("/var/lib/syncthing/bar")
      b.wait_for_file("/var/lib/syncthing/bar")
      c.wait_for_file("/var/lib/syncthing/bar")

      a.succeed("echo plaincontent > /var/lib/syncthing/bar/plainname")

      # Bar on C is untrusted, check that content is not in cleartext
      c.fail("grep -R plaincontent /var/lib/syncthing/bar")

      # Test baz

      a.wait_for_file("/var/lib/syncthing/baz")
      b.wait_for_file("/var/lib/syncthing/baz")
      c.wait_for_file("/var/lib/syncthing/baz")

      # A creates the file notB, C should get it, B should ignore it
      a.succeed("echo notB > /var/lib/syncthing/baz/notB")
      a.succeed("echo controlA > /var/lib/syncthing/baz/controlA")
      c.wait_for_file("/var/lib/syncthing/baz/notB")
      c.wait_for_file("/var/lib/syncthing/baz/controlA")
      b.wait_for_file("/var/lib/syncthing/baz/controlA")

      # B creates the file notC, A should get it, C should ignore it
      b.succeed("echo notC > /var/lib/syncthing/baz/notC")
      b.succeed("echo controlB > /var/lib/syncthing/baz/controlB")
      a.wait_for_file("/var/lib/syncthing/baz/notC")
      a.wait_for_file("/var/lib/syncthing/baz/controlB")
      c.wait_for_file("/var/lib/syncthing/baz/controlB")

      # Check that files have been correctly ignored
      b.fail("cat /var/lib/syncthing/baz/notB")
      c.fail("cat /var/lib/syncthing/baz/notC")

      # Test foo bar

      a.wait_for_file("/var/lib/syncthing/foo-bar")
      b.wait_for_file("/var/lib/syncthing/foo-bar")

      a.succeed("echo a2b > /var/lib/syncthing/foo-bar/a2b")
      a.succeed("echo a2b > /var/lib/syncthing/foo-bar/notB")
      b.succeed("echo b2a > /var/lib/syncthing/foo-bar/b2a")

      a.wait_for_file("/var/lib/syncthing/foo-bar/b2a")
      b.wait_for_file("/var/lib/syncthing/foo-bar/a2b")

      # Check that file has been correctly ignored
      b.fail("cat /var/lib/syncthing/foo-bar/notB")

      # Through the Syncthing API:
      #
      # - On B: configure and share folder baz with A;
      # - On A: configure and share folder baz with B;
      # - On A: add device D.
      #
      # Then restart syncthing-init.service and
      # make sure that those changes are persisted.
      nodeIdA = a.succeed("cat ${nodeDirs.a}/id").strip()
      nodeIdB = a.succeed("cat ${nodeDirs.b}/id").strip()
      folder = "baz"

      def share_folder_with(nodeId: str) -> str:
        # Prepare an API request to create a new
        # folder and share it with the given node.
        return json.dumps({
          "autoNormalize": False, # upstream default is True
          "caseSensitiveFS": True, # upstream default is False
          "copyOwnershipFromParent":False,
          "devices": [
            {"deviceId": nodeId},
          ],
          "enable":True,
          "id": folder,
          "label": folder,
          "path": f"/var/lib/syncthing/{folder}",
          "type": "sendreceive",
          "versioning": None,
        })

      def pause_device_b(nodeId: str) -> str:
        return json.dumps({
          "paused": True,
          "deviceID": nodeIdB,
          "id": nodeIdB,
          "name": "b",
        })

      def post(what: str, node, req: str):
        cmd = shlex.join([
          "st-curl",
          f"/rest/config/{what}",
          "-X", "POST",
          "-d", req,
        ])
        return node.succeed(cmd)

      config_folders = functools.partial(post, "folders")
      config_devices = functools.partial(post, "devices")

      def check_folder(node):
        cmd = shlex.join(["st-curl", "/rest/config/folders"])
        folders = json.loads(node.succeed(cmd))
        def baz_only(f): return f["path"] == f"/var/lib/syncthing/{folder}"
        # the type check coerced me to use list...
        baz_folder = list(filter(baz_only, folders))
        how_many = len(baz_folder)
        assert how_many == 1, f"expected 1 {folder} folder (got {how_many})"
        case_sensitive_fs = baz_folder[0]["caseSensitiveFS"]
        auto_normalize = baz_folder[0]["autoNormalize"]
        assert case_sensitive_fs is True, f"caseSensitiveFS was reset to {case_sensitive_fs}"
        assert auto_normalize is False, f"autoNormalize was reset to {auto_normalize}"

      def check_device(node):
        cmd = shlex.join(["st-curl", "/rest/config/devices"])
        devices = json.loads(node.succeed(cmd))
        device_b = [d for d in devices if d["deviceID"] == nodeIdB]
        how_many = len(device_b)
        assert how_many == 1, f"expected 1 device for nodeID B (got {how_many})"
        assert device_b[0]["paused"] == True, "syncthing-init shouldn't have unpaused B"

      config_folders(a, share_folder_with(nodeIdB))
      config_folders(b, share_folder_with(nodeIdA))
      config_devices(a, pause_device_b(nodeIdB))

      check_folder(a)
      check_folder(b)
      check_device(a)

      a.systemctl("restart syncthing-init.service")
      b.systemctl("restart syncthing-init.service")

      check_folder(a)
      check_folder(b)
      check_device(a)
    '';
}
