{
  description = "tmux configuration as a home-manager homeModule";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    {
      homeModules.default = import ./home.nix;

      # tmux-config 単体でビルド検証するための homeConfiguration。
      # home-manager を input に取り、自身の homeModule を読み込んで home を組む。
      homeConfigurations.default = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        modules = [
          self.homeModules.default
          {
            home.username = "tmux-config";
            home.homeDirectory = "/home/tmux-config";
            home.stateVersion = "25.05";
            myTmux.enable = true;
            # programs.zsh.initContent をマージするには zsh が有効である必要がある。
            programs.zsh.enable = true;
          }
        ];
      };
    };
}
