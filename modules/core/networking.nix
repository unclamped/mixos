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
}
