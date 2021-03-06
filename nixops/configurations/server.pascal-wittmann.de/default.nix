{

  network = {
   enableRollback = true;
  };

  server = { config, pkgs, lib, ... }:

  {
    require = [
      ./modules/homepage.nix
      ./modules/subsonic.nix
      ./modules/radicale.nix
      ./users.nix
    ];

    deployment.targetHost = "server.pascal-wittmann.de";

    # Use the GRUB 2 boot loader.
    boot.loader.grub.enable = true;
    boot.loader.grub.version = 2;
    # Define on which hard drive you want to install Grub.
    boot.loader.grub.device = "/dev/vda";

    boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci"
      "virtio_blk" ];
    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/7d067332-eba7-4a8e-acf7-a463cf50677f";
      fsType = "ext4";
    };

    swapDevices = [
      { device = "/dev/disk/by-uuid/279e433e-1ab9-4fd1-9c37-0d7e4e082944"; }
    ];

    nix.maxJobs = 2;
    nix.gc.automatic = true;
    nix.gc.dates = "06:00";

    system.autoUpgrade.enable = false;
    system.autoUpgrade.channel = https://nixos.org/channels/nixos-17.09;
    system.autoUpgrade.dates = "11:00";
    systemd.services.nixos-upgrade.environment.NIXOS_CONFIG = pkgs.writeText "configuration.nix" ''
      all@{ config, pkgs, lib, ... }: lib.filterAttrs (n: v: n != "deployment") ((import /etc/nixos/current/default.nix).server all)
    '';

    system.activationScripts = {
      configuration = ''
        rm /etc/nixos/current/* #*/
        ln -s ${./.}/* /etc/nixos/current #*/
      '';
    };

    # Work around NixOS/nixpkgs#28527
    systemd.services.nixos-upgrade.path = with pkgs; [  gnutar xz.bin gzip config.nix.package.out ];

    networking.hostName = "nixos"; # Define your hostname.

    networking.firewall.rejectPackets = true;
    networking.firewall.allowPing = true;
    networking.firewall.autoLoadConntrackHelpers = false;
    networking.firewall.allowedTCPPorts = [
      80 # http
      443 # https
      4242 # quassel
    ];

    # Select internationalisation properties.
    i18n = {
      consoleFont = "Lat2-Terminus16";
      consoleKeyMap = "de";
      defaultLocale = "en_US.UTF-8";
    };

    # Set your time zone.
    time.timeZone = "Europe/Berlin";

    # Security - PAM
    security.pam.loginLimits = [ {
      domain = "*";
      item = "maxlogins";
      type = "-";
      value = "3";
    } ];

    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    environment.systemPackages = with pkgs; [
      # Install only the urxvt terminfo file
      rxvt_unicode.terminfo
      zile
    ];

    # List services that you want to enable:

    # Cron daemon.
    services.cron.enable = true;
    services.cron.systemCronJobs = [
      "30 2 * * * root start nixpkgs-monitor-updater"
    ];

    # Enable the OpenSSH daemon
    services.openssh.enable = true;
    services.openssh.allowSFTP = true;
    services.openssh.forwardX11 = false;
    services.openssh.permitRootLogin = "yes"; # For deployment via NixOps
    services.openssh.passwordAuthentication = false;
    services.openssh.challengeResponseAuthentication = false;

    # bitlbee.
    services.bitlbee.enable = true;
    services.bitlbee.interface = "127.0.0.1";
    services.bitlbee.portNumber = 6667;
    services.bitlbee.authMode = "Registered";
    services.bitlbee.hostName = "server.pascal-wittmann.de";
    services.bitlbee.configDir = "/srv/bitlbee";

    # quassel
    services.quassel.enable = true;
    services.quassel.interfaces = [ "0.0.0.0" ];
    services.quassel.dataDir = "/srv/quassel";

    # PostgreSQL.
    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql94;
    services.postgresql.authentication = lib.mkForce ''
    # Generated file; do not edit!
    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    local   all             all                                     trust
    host    all             all             127.0.0.1/32            trust
    host    all             all             ::1/128                 trust
    '';

    # Caldav / Cardav
    services.radicale.enable = true;
    services.radicale.config = ''
      [server]
      hosts = 127.0.0.1:5232
      ssl = False
      
      [storage]
      filesystem_folder = /srv/radicale/collections
    '';
    services.radicale.package = pkgs.radicale2;
    services.radicale.nginx.enable = true;
    services.radicale.nginx.hostname = "calendar.pascal-wittmann.de";

    # Subsonic
    services.subsonic.enable = true;
    services.subsonic.defaultMusicFolder = "/srv/music";
    services.subsonic.defaultPlaylistFolder = "/srv/playlists";
    services.subsonic.defaultPodcastFolder = "/srv/podcast";
    services.subsonic.httpsPort = 0;
    services.subsonic.listenAddress = "127.0.0.1";
    services.subsonic.nginx.enable = true;
    services.subsonic.nginx.hostname = "music.pascal-wittmann.de";

    # ngix
    services.nginx.enable = true;
    services.nginx.virtualHosts = {
       "penchy.pascal-wittmann.de" = {
         forceSSL = true;
         enableACME = true;
         root = "/srv/penchy";
       };

       "users.pascal-wittmann.de" = {
         forceSSL = true;
         enableACME = true;

         locations."/pascal" = {
           root = "/srv/users/";
           extraConfig = ''
             autoindex on;
             auth_basic "Password protected area";
             auth_basic_user_file ${./secrets/passwords};
           '';
         };

         locations."/lerke" = {
           root = "/srv/users/";
           extraConfig = ''
             autoindex on;
             auth_basic "Password protected area";
             auth_basic_user_file ${./secrets/passwords};
           '';
         };
         extraConfig = ''
           add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
           add_header X-Content-Type-Options nosniff;
           add_header X-XSS-Protection "1; mode=block";
           add_header X-Frame-Options DENY;
         '';
       };
    };

    # Homepage
    services.homepage.enable = true;

    # Netdata
    services.netdata.enable = true;

    # Graylog
    services.graylog.enable = true;
    services.graylog.passwordSecret = import ./secrets/graylog-password-secret;
    services.graylog.rootPasswordSha2 = import ./secrets/graylog-root-password-sha2;
    services.graylog.elasticsearchHosts = [ "http://127.0.0.1:9200" ];
    services.elasticsearch.enable = true;
    services.mongodb.enable = true;
    services.SystemdJournal2Gelf.enable = true;
    services.SystemdJournal2Gelf.graylogServer = "127.0.0.1:12201";

    services.syncthing.enable = true;
    services.syncthing.openDefaultPorts = true;

    # Sound
    sound.enable = false;

    # Enable zsh
    programs.zsh.enable = true;

    # X-libraries and fonts are not needed on the server.
    #  environment.noXlibs = true;
    fonts.fontconfig.enable = false;

    users.mutableUsers = false;
    users.defaultUserShell = "${pkgs.zsh}/bin/zsh";
  };
}
