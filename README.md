# Foreman Azure

## Description
Plugin to add [Microsoft Azure Resource Manager](http://azure.com/) as a compute resource for [The Foreman](http://theforeman.org/)

## Features
* Managed disks support
* Support for most typical IaaS operations
    * VM creation
    * Multiple NICs
    * Multiple data disks, premium or not
    * Static or dynamic addresses on a per NIC basis
* Limited extension support
    * Microsoft's custom script extension
    * Puppet Lab's Puppet agent extension for Windows
    
## Planned Features
* Improved extension support    
    
## Known Limitations
* Most Azure marketplace images (likely all of them) disallow direct root login, which means SSH provisioning 
with The Foreman has limited functionality. A workaround is to provide a dummy user data template and do all
post-provisioning with the custom script extension 