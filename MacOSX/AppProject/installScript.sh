#!/bin/sh

#  installScript.sh
#  iDevicePaired
#
#  Created by Rodol on 2/4/17.
#
#LoginItem Scripts
#list: osascript -e 'tell application "System Events" to get the name of every login item'
#add: osascript -e 'tell application "System Events" to make login item at end with properties {path:"/path/to/itemname", hidden:false}'
#remove: osascript -e 'tell application "System Events" to delete login item "itemname"'
#Install Daemon by app
#install by app :sudo open /Applications/iDevicePairedTool.app --args installDaemon

sudo launchctl load /Library/LaunchDaemons/com.11paths.iDevicePaired.HelperTool.plist

sudo security -q authorizationdb write "com.11paths.iDevicePaired.readDevicesPaired" allow
sudo security -q authorizationdb write "com.11paths.iDevicePaired.deleteDevicePaired" allow
sudo security -q authorizationdb write "com.11paths.iDevicePaired.checkDevicePaired" allow

osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/iDevicePairedTool.app", hidden:false}'
open /Applications/iDevicePairedTool.app

