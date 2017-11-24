#! /bin/sh

#  Uninstall.sh
#  iDevicePaired
#
#  Created by Rodol on 2/4/17.
#



sudo launchctl unload /Library/LaunchDaemons/com.11paths.iDevicePaired.HelperTool.plist
sudo rm /Library/LaunchDaemons/com.11paths.iDevicePaired.HelperTool.plist
sudo rm /Library/PrivilegedHelperTools/com.11paths.iDevicePaired.HelperTool

sudo rm -rf /Applications/iDevicePairedTool.app
osascript -e 'tell application "System Events" to delete login item "iDevicePairedTool"'


sudo security -q authorizationdb remove "com.11paths.iDevicePaired.readDevicesPaired"
sudo security -q authorizationdb remove "com.11paths.iDevicePaired.deleteDevicePaired"
sudo security -q authorizationdb remove "com.11paths.iDevicePaired.checkDevicePaired"


