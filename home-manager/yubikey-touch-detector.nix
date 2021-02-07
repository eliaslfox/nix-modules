{ pkgs, lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.services.yubikey-touch-detector;
in
{
  options.services.yubikey-touch-detector = {
    enable = mkEnableOption "Enable yubikey-touch-detector support";
    package = mkOption {
      type = types.package;
      description = "Package to use for yubikey-touch-detector";
      example = "nur.repos.mic92.yubikey-touch-detector";
    };
    environment = mkOption {
      type = types.listOf types.str;
      description = "Environment for yubikey-touch-detector systemd unit";
      default = [
        "YUBIKEY_TOUCH_DETECTOR_VERBOSE=true"
        "YUBIKEY_TOUCH_DETECTOR_LIBNOTIFY=true"
      ];
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ cfg.package ];
    systemd.user.services.yubikey-touch-detector = {
      Unit = { Description = "Yubikey touch detector daemon"; After = [ "graphical.target" ]; };
      Service = {
        ExecStart = "${cfg.package}/bin/yubikey-touch-detector";
        Environment = cfg.environment ++ [
          "PATH=${pkgs.gnupg}/bin"
        ];
      };
      Install = { WantedBy = [ "default.target" ]; };
    };
    systemd.user.sockets.yubikey-touch-detector = {
      Unit = { Description = "Socket for yubikey touch detector daemon"; };
      Socket = {
        ListenStream = "%t/yubikey-touch-detector.socket";
        RemoveOnStop = "yes";
      };
      Install = { WantedBy = [ "sockets.target" ]; };
    };
  };
}
