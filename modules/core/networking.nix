{ config, ... }:

{
  # NetworkManager for easy network management
  networking = {
    networkmanager.enable = true;
    
    # Firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };
  };
  
  # Ensure NetworkManager connections persist
  environment.persistence."/persist" = {
    directories = [
      "/etc/NetworkManager/system-connections"
    ];
  };
}
