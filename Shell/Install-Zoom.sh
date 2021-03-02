#!/bin/bash

####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
# Install-Zoom.sh
#
# SYNOPSIS
# sudo Install-Zoom.sh
#
# DESCRIPTION
# Grabs the latest IT installer for zoom via curl to install Zoom meeting app.
#
# Note
#
# You the executor, runner, user accept all liability.
# This code comes with ABSOLUTELY NO WARRANTY.
# You may redistribute copies of the code under the terms of the GPL v3.
#
####################################################################################################
#
# HISTORY
#
#	Version: 2.0 (Mostly Tested on Catalina and Big Sur.)
#
#	- Created by Axel Garcia on March 1th, 2021
# 
####################################################################################################

# Log location
logfile="/var/log/scripts/Install-Zoom.log"
Logfolder="/var/log/scripts/"

# Logging Tool
LoggingTool() {
  echo "${1}"
  echo "`date`: ${1}" >> ${logfile}
}

#verifying log folder location exists
if [ -d $Logfolder ]; then
	LoggingTool "Log Directory Exists"
else
	mkdir $Logfolder
	LoggingTool "Making Log Directory"
fi

LoggingTool "Installing Zoom"

#set up for curl
Zoomfile="Zoom.pkg"
OSvers_URL=$( sw_vers -productVersion | sed 's/[.]/_/g' )
userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"
latestver=`/usr/bin/curl -s -A "$userAgent" https://zoom.us/download | grep 'ZoomInstallerIT.pkg' | awk -F'/' '{print $3}'`
#downloading zoom
Zoomurl="https://zoom.us/client/${latestver}/ZoomInstallerIT.pkg"
curl -sLo /tmp/${Zoomfile} ${Zoomurl} &&
#Install Zoom
installer -allowUntrusted -pkg /tmp/${Zoomfile} -target /
#Clean up
rm /tmp/${Zoomfile}
