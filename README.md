wifriedx
========

Band-aid for Yosemite WiFi issues caused from AWDL (even when the user is not specifically using AWDL/AirDrop).   
  
More detail at https://medium.com/@mariociabarra/wifriedx-in-depth-look-at-yosemite-wifi-and-awdl-airdrop-41a93eb22e48   
   
Summed up, it's a glorified "sudo ifconfig awdl0 down" that monitors the interface and brings it back down if needbe.  
  
- Runs at Login  
- Uninstalls Daemon on the following boot after the App is deleted.   

Contains:
  - Menu bar item which monitors the interface and sends commands to daemon helper
  - SMBlessed PriviledgedHelper daemon to bring the interface up/down

VERSION 1.2 ChangeLog:  
- Support for OS X dark menu bar by kirb (Adam D)  
      
  
Uninstall Note: If a user does not uncheck launch at login in the app before deleting the app, ther user can uncheck under Preferences -> User Accounts -> Login Items.  The entry is simply an entry in the launch login item plist, but just to be clear.
