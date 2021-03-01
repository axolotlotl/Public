#!/bin/bash

####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	Install-brew.sh
#
# SYNOPSIS
# sudo Install-Brew.sh
#
# DESCRIPTION
#	This does 4 things: Installs Xcode if missing, Downloads Brew tarball, Sets correct permissions for necessary folders, and can install brew apps as login user. 
#	This script is meant to be run from an MDM tool or as sudo.
#
# Xcode install requires pre-approval for Terminal to Accesibility since it uses Front-End automation for "tell" portion of the script.
# Install Brew Portion requres pre-approval for Terminal to Full Disk write to be able to modify directories /usr/local/ (10.15+)
# https://github.com/jamf/PPPC-Utility/releases is a good tool to figure this part out. 
#
# This script is intended for orgs that want to pre-install brew + apps or do not allow admin right to local accounts but need to install brew.
#
# Note
# Read script before deployment, Sections are commented out for expansion or optional features.
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
logfile="/var/log/scripts/Install-Brew.log"
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

# Get console user
LoggingTool "getting loggedin user info"
user=`ls -l /dev/console | awk '{print $3}'`

# Install Xcode CLI tools
if [ ! -d /Library/Developer/CommandLineTools ]; then 

  LoggingTool "Installing Xcode"
  xcode-select --install

  sleep 1

  osascript <<EOD
  tell application "System Events"
    tell process "Install Command Line Developer Tools"
      keystroke return
      click button "Agree" of window "License Agreement"
    end tell
  end tell
EOD

  sleep 1

  # Exit for Update tool once complete
  function closeupdate {
  osascript <<EOD
  try
	  tell application "System Events"
		  tell process "Install Command Line Developer Tools"
			  if exists ( button "Done" of window "")
			    click ( button "Done" of window "")
        else
          delay 0.1
        end if
		  end tell
  	end tell
  end try
EOD
  }

  # Wait for download and install to complete
  Process=`pgrep "Install Command Line Developer Tools"`
  until [ -z $Process ]; do
    sleep 4
    Process=`pgrep "Install Command Line Developer Tools"`
    closeupdate 2>/dev/null
  done

else 
    LoggingTool "Xcode is already installed"
fi

# Install Brew
LoggingTool "Installing brew"
if [ ! -d /Library/Developer/CommandLineTools ]; then 
  LoggingTool "Xcode failed to install"
  exit 1

else

  # Is homebrew already installed?
  if [[ ! -e /usr/local/bin/brew ]]; then
    # Install Homebrew. This doesn't like being run as root so we must do this manually.

    mkdir -p /usr/local/Homebrew
    # Curl down the latest tarball and install to /usr/local
    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /usr/local/Homebrew

    # Manually make all the appropriate directories and set permissions
    mkdir -p /usr/local/Cellar /usr/local/Homebrew /usr/local/Frameworks /usr/local/bin /usr/local/etc
    mkdir -p /usr/local/include /usr/local/lib /usr/local/opt /usr/local/sbin
    mkdir -p /usr/local/share/zsh/site-functions /usr/local/var
    mkdir -p /usr/local/share/doc /usr/local/man/man1 /usr/local/share/man/man1
    chown -R "${user}":_developer /usr/local/*
    chmod -R g+rwx /usr/local/*
    chmod 755 /usr/local/share/zsh /usr/local/share/zsh/site-functions

    # Create a system wide cache folder  
    mkdir -p /Library/Caches/Homebrew
    chmod g+rwx /Library/Caches/Homebrew
    chown "${user}:_developer" /Library/Caches/Homebrew

    # Put brew where we can find it
    ln -s /usr/local/Homebrew/bin/brew /usr/local/bin/brew

    # Install the MD5 checker or the recipes will fail
    su -l "$user" -c "/usr/local/bin/brew install md5sha1sum"
    echo 'export PATH="/usr/local/opt/openssl/bin:$PATH"' | \
	  tee -a /Users/${user}/.bash_profile /Users/${user}/.zshrc
    chown ${user} /Users/${user}/.bash_profile /Users/${user}/.zshrc
    
    # Cleaning some directory permissions issues with 10.15+
    chown -R root:wheel /private/tmp
    chmod 777 /private/tmp
    chmod +t /private/tmp
  fi

    # Install all the default grail developer tools
    su -l "${user}" -c "/usr/local/bin/brew update"

    #Installing brew apps.
    LoggingTool "installing git with brew"
    su -l "${user}" -c "brew install git"

    #LoggingTool "installing awscli with brew"
    #su -l "${user}" -c "brew install awscli"

    #LoggingTool "installing yarn with brew"
    #su -l "${user}" -c "brew install yarn"

    #Makes sure Brew is working correctly
    LoggingTool "Cleaning up brew"
    su -l "${user}" -c "brew cleanup"

  # Create an ssh key for the user (optional)
    #LoggingTool "Creating SSH key"
    #mkdir /Users/${user}/.ssh
    #ssh-keygen -N '' -f /Users/${user}/.ssh/id_rsa
    #chown -h -R ${user} /Users/${user}/.ssh/*

  # Change owner of /usr/local -- where brew installs everything
  LoggingTool "Setting up /usr/local"
  chown -h -R ${user} /usr/local/*
fi
