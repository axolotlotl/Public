#!/bin/bash
####################################################################################################
#
# Copyright (c) 2020, Netskope, Inc.  All rights reserved.
#
#
####################################################################################################
#
# SUPPORT FOR THIS PROGRAM
#
#       This program is distributed "as is" by Netskope, Inc team. Please contact Netskope support
#       team.
#
####################################################################################################
#
# ABOUT THIS PROGRAM
#
# VERSION : 20.0
#
# NAME
#		nsclientconfig.sh -- file copies NS Client install param file(nsinstparams.json) from customer
#       tenant for logged-in user.
#
# SYNOPSIS
#		nsclientconfig.sh <dummy param 1> <dummy param 2> <currentUsername> <tenant url> > <org Key> <UPN <optional>>
#       nsinstparams.json file.
#
# DESCRIPTION
#       nsclientconfig.sh is written for AD registed user and JSS controller machine and email address into
#       consumed by Netskope Client installer.
#
####################################################################################################
# version : 1.0 , this script file is introduced for jamf based installation
# version : 2.0 , support Client installation by UPN
# version : 3.0 , support for perUserMode installations in mac
# version : 4.0 , script to read email from preference file, and configuring installtion for cli_mode
# version : 5.0 , Fixed output redirection to ${NSINSTPARAM_JSON_FILE} variable
# version : 6.0 , [2019-Oct-10] Added support for IdP mode installation in mac
# version : 7.0 , [2019-Oct-25] Added support for requestEmail in IdP mode installation
# version : 8.0 , [2019-Nov-19] Corrected quotes for NSINSTPARAM_JSON_FILE
# version : 9.0 , [2019-Dec-11] Added multi user support for IdP mode
# version : 10.0 , [2020-Apr-24] Fixed addonUrl should have "addon-" prefix issue
# version : 11.0 , [2020-Jun-05] Retrive correct filename from file with multiple . in name
# version : 12.0 , [2020-Jun-09] Added support for fail-close
# version : 13.0 , [2020-Sep-23] Fixed installer fallback to idP mode issue
# version : 14.0 , [2020-Nov-23] Removed python dependency to fetch email address
# version : 15.0 , [2021-Jan-18] Support to specify email address for UPN installation through plist file
# version : 16.0 , [2021-Sept-07] Depricated Rest API Token. Replaced org key in place of Rest API token.
#                                 Version 16.0 + script should be used with R90+ client. Version 15 or earlier
#                                 version script should use older client version (Client version < R90).
# version : 17.0 , [2022-March-15] Added support for silent mode
# version.: 18.0 , [2022-March-20] Added support for enrollment tokens
# version.: 19.0 , [2023-Jan-11] Bug fixes
# version.: 20.0 , [2023-Aug-03] Addition of nsidpconfig.json options mode=[embedded|scheme] and preferephemeral
####################################################################################################
# Update here for Intune deployment.
# please refer https://docs.netskope.com/en/microsoft-intune.html for more details.
#
# example for IDP mode
# set -- 0 0 0 idp <Domain name> <Tenant name> <Email Address request option - 0/1>
#
# example for UPN mode - AD joined machine
# set -- 0 0 0 <addon-host> <org-key> upn
#



# End of section for Intune deployment.
####################################################################################################

argstring="$*"

upnmode=0
perusermode=0
email_from_pref=0
cli_mode=0
idP_mode=0
silent_mode=0
enrollauthtoken=0
enrollencryptiontoken=0
enroll_key_mode=0

if echo "$argstring" | grep -q "upn"; then
    echo "Installation is configured for upn based branding"
    upnmode=1
fi

if echo "$argstring" | grep -q "peruserconfig"; then
    echo "Installation is configured for peruserconfig mode"
    perusermode=1
fi

if echo "$argstring" | grep -q "preference_email"; then
    echo "Installation is configured with preference_email"
    email_from_pref=1
fi

if echo "$argstring" | grep -q "cli_mode"; then
    echo "Installation is configured with cli_mode   "
    cli_mode=1
fi


if echo "$argstring" | grep -iq "idp"; then
    echo "Installation is configured for Idp mode install"
    idP_mode=1
fi

if echo "$argstring" | grep -iq "silent_mode"; then
    echo "Installation is configured for silent mode install"
    silent_mode=1
fi

argArray=(`echo $argstring | tr  ' ' ' '`)
for arg in "${argArray[@]}"
do

    if [[ "$arg" =~ "enrollauthtoken" ]]; then
        echo "matched enrollauthtoken"
        enrollauthtoken=1
        enrollauthtoken_option=(`echo "$arg" | awk -F"=" '{print $2}'`)
        enrollauthtoken_option="\"enrollauthtoken\": \"${enrollauthtoken_option}\""
               echo "enroll using auth token"
    fi
    
    if [[ "$arg" =~ "enrollencryptiontoken" ]]; then
        echo "matched enrollencryptiontoken"
        enrollencryptiontoken=1
        enrollencryptiontoken_option=(`echo "$arg" | awk -F"=" '{print $2}'`)
               enrollencryptiontoken_option="\"enrollencryptiontoken\": \"${enrollencryptiontoken_option}\""
               echo "enroll using ecryption token"
    fi

    if [[ "$arg" =~ "mode" ]]; then
        echo "matched IDP browser mode"
        browser_mode=(`echo "$arg" | awk -F"=" '{print $2}'`)
        browser_mode=", \"mode\": \"${browser_mode}\""
    fi

    if [[ "$arg" =~ "preferephemeral" ]]; then
        echo "matched IDP preferephemeral"
        prefer_ephemeral=(`echo "$arg" | awk -F"=" '{print $2}'`)
        prefer_ephemeral=", \"preferEphemeral\": ${prefer_ephemeral}"
    fi

done

TEMP_BRANDING_DIR="/tmp/nsbranding"
NSINSTPARAM_JSON_FILE="$TEMP_BRANDING_DIR/nsinstparams.json"
TEMP_SILENTMODE_FILE="$TEMP_BRANDING_DIR/silent.conf"
TEMP_ENROLLMENT_TOKEN_FILE="$TEMP_BRANDING_DIR/enroll.conf"
NSUSERCONFIG_JSON_FILE="/Library/Application Support/Netskope/STAgent/nsuserconfig.json"
NSIDPCONFIG_FILE_PATH="/Library/Application Support/Netskope/STAgent/nsidpconfig.json"

optionalArgumentCnt=`expr $silent_mode + $enrollauthtoken + $enrollencryptiontoken`
minimumArg=`expr 6 + $optionalArgumentCnt`

if [ $# -lt $minimumArg ] && [ $idP_mode -eq 0 ]; then
   echo "Insufficient arguments."
   echo "Usage: nsclientconfig.sh for email based, <dummy param 1> <dummy param 2>  <currentUsername> <tenant url> <AD domain name> <Org Key> [silent_mode] [enrollauthtoken=token] [enrollencryptiontoken=token]"
   echo "Usage: nsclientconfig.sh for upn based, <dummy param 1> <dummy param 2>  <currentUsername> <Adonman url>  <Org Key> <upn> [preference_file_name] [silent_mode] [enrollauthtoken=token] [enrollencryptiontoken=token]"
   echo "Usage: nsclientconfig.sh for peruserconfig mode , <dummy param 1> <dummy param 2>  <currentUsername> <Adonman url>  <Org Key> <peruserconfig> [fail-close fail-close-disable/fail-close-no-npa] [silent_mode] [enrollauthtoken=token] [enrollencryptiontoken=token]"
   echo "Usage: nsclientconfig.sh for reading email from preference file mode , <dummy param 1> <dummy param 2> <dummy param 3> <tenant url> <Org Key> <preference_file_name> preference_email [silent_mode] [enrollauthtoken=token] [enrollencryptiontoken=token]"
   echo "Usage: nsclientconfig.sh for reading logged in user using CLI tools, <dummy param 1> <dummy param 2> <dummy param 3> <tenant url> <Org Key> cli_mode [silent_mode]"
   echo "Usage: nsclientconfig.sh for IdP mode , <dummy param 1> <dummy param 2>  <dummy param 3> idp <domain> <tenant> <requestEmail 1/0> [peruserconfig] [fail-close fail-close-disable/fail-close-no-npa] [silent_mode] [enrollauthtoken=token] [enrollencryptiontoken=token] [mode=embedded|scheme] [preferephemeral=true|false]"
   exit 1
fi

# Remove the old directory if exists
rm -rf $TEMP_BRANDING_DIR
mkdir -p $TEMP_BRANDING_DIR

echo "Param1 $1 Param2 $2 Param3 $3"
allrunningusers=`users`
loggedinusername=`stat -f '%Su' /dev/console`
echo "All Logged in user names: $allrunningusers"
echo "Logged in user name: $loggedinusername"
#
# Set parameters.
#
userName="$3"
echo "User name is $userName length ${#userName}"

if [ "$userName" == "0" ]; then
    userName=$loggedinusername
fi

echo "User name is $userName length ${#userName}"

if [ $idP_mode -eq 0 ]; then
    echo "Going to remove IdP config file"
    rm -f "${NSIDPCONFIG_FILE_PATH}"
fi

fail_close="false"
fail_close_no_npa="false"

if echo "$argstring" | grep -iq "fail-close-disable"; then
    echo "Fail close disable option is provided"
    fail_close="true"
fi

if echo "$argstring" | grep -iq "fail-close-no-npa"; then
    echo "Fail close no-npa option is provided"
    fail_close="true"
    fail_close_no_npa="true"
fi

fail_close_option=""
if [ "$fail_close" = "true" ]; then
    fail_close_option=",\"failClose\": {\"fail_close\": \"$fail_close\",\"exclude_npa\": \"$fail_close_no_npa\"}"
fi

if [ $silent_mode -eq 1 ]; then
    echo "1" > "${TEMP_SILENTMODE_FILE}"
fi

if [ $enrollauthtoken -eq 1 ] || [ $enrollencryptiontoken -eq 1 ]; then 
	echo "enrollment tokens detected..."
	
	enrollmentJSON="{" 
	enrollmentJSON="$enrollmentJSON$enrollauthtoken_option"
	
	if [ $enrollauthtoken -eq 1 ] && [ $enrollencryptiontoken -eq 1 ]; then
		enrollmentJSON="$enrollmentJSON," 
	fi
	
	enrollmentJSON="$enrollmentJSON $enrollencryptiontoken_option"
	enrollmentJSON="$enrollmentJSON}"
	
	echo "$enrollmentJSON" > "$TEMP_ENROLLMENT_TOKEN_FILE"
else
     echo "" > "$TEMP_ENROLLMENT_TOKEN_FILE"
fi 

chmod 700 "$TEMP_ENROLLMENT_TOKEN_FILE"

if [ $idP_mode -eq 1 ]
then
    mkdir -p "/Library/Application Support/Netskope/STAgent"

    spDomain="$5"
    echo "IdP Service Provider Domain is $spDomain"

    spTenant="$6"
    echo "IdP Service Provider Tenant key is $spTenant"

	requestEmailNode=" "
	if [ $# -gt 6 ] && [ $7 -gt 0 ]; then
        echo "IdP requestEmail is provied"
		requestEmailNode=", \"requestEmail\": \"true\" "
	fi

    echo "{ \"serviceProvider\": { \"domain\": \"$spDomain\", \"tenant\": \"$spTenant\" ${browser_mode} ${prefer_ephemeral} } $requestEmailNode }" > "${NSIDPCONFIG_FILE_PATH}"

    if [ $perusermode -eq 1 ]
    then
        mkdir -p "/Library/Application Support/Netskope/STAgent"

        echo "{\"nsUserConfig\":{\"enablePerUserConfig\": \"true\", \"configLocation\": \"~/Library/Application Support/Netskope/STAgent\", \"token\": \"\", \"host\": \"\",\"autoupdate\": \"true\"$fail_close_option}}" > "${NSUSERCONFIG_JSON_FILE}"

    fi

exit 0
fi

if [ $perusermode -eq 1 ]
then
    # Create the empty install param json file so that IDP mode will not trigger in case of any failure
    echo -n > "${NSINSTPARAM_JSON_FILE}"

    mkdir -p "/Library/Application Support/Netskope/STAgent"

    addonUrl="$4"
    echo "Addonman url is $addonUrl"

    if [[ $addonUrl != addon-* ]]; then
        echo "Addonman url does not start with addon-"
        exit 1
    fi

    orgkey="$5"

    echo "{\"nsUserConfig\":{\"enablePerUserConfig\": \"true\", \"configLocation\": \"~/Library/Application Support/Netskope/STAgent\", \"token\": \"$orgkey\", \"host\": \"$addonUrl\",\"autoupdate\": \"true\"$fail_close_option}}" > "${NSUSERCONFIG_JSON_FILE}"

exit 0
fi

if [ $email_from_pref -eq 1 ]
then
    # Create the empty install param json file so that IDP mode will not trigger in case of any failure
    echo -n > "${NSINSTPARAM_JSON_FILE}"

     tenantUrl="$4"
     echo "Tenant url is $tenantUrl"

     orgKey="$5"

     emailPrefFile='/Library/Managed Preferences/'$6
     echo  "email pref file path $emailPrefFile"

    if [ ! -f "$emailPrefFile" ]
    then
        echo "$emailPrefFile not found, exiting installation process"
        exit 1
    fi

    plistFilename="$(echo $6 | rev | cut -c7- | rev)"
    emailAddress=`defaults read "$emailPrefFile" email`
    
    # error handling after plist is read
    if [ $? != 0 ]
    then
        echo "failed to read email address from preference file, exiting installation process error code $?"
        exit 1
    fi
    echo "$emailAddress Email Address in defaults preference"

    IFS='@'
    typeset -r splitEmailAddr2=($emailAddress)

    if [ ${#splitEmailAddr2[@]} -ne 2 ]
    then
        echo "Invalid email address, existing installation process"
        exit
    fi

    echo "$emailAddress Email Address in defaults preference"

    mkdir -p $TEMP_BRANDING_DIR

    echo "{\"TenantHostName\":\"$tenantUrl\", \"Email\":\"$emailAddress\", \"OrgKey\":\"$orgKey\"}" > "${NSINSTPARAM_JSON_FILE}"

    if [ $? == 0 ]
    then
        echo "$NSINSTPARAM_JSON_FILE created successfully"
        exit 0
    fi

    echo "Failed to create $NSINSTPARAM_JSON_FILE file"
    exit 1
fi

if [ $cli_mode -eq 1 ]
then
    # Create the empty install param json file so that IDP mode will not trigger in case of any failure
    echo -n > "${NSINSTPARAM_JSON_FILE}"

     tenantUrl="$4"
     echo "Tenant url is $tenantUrl"

     orgKey="$5"
	
	# Extract logged in user's email using CLI tools 
    emailAddress=$(adquery user "$loggedinusername" -P)
    
    if [ $? != 0 ]
    then
        echo "failed to read email address from CLI, exiting installation process error code $?"
        exit 1
    fi

    echo "Logged in user is : $emailAddress"

    mkdir -p $TEMP_BRANDING_DIR

    echo "{\"TenantHostName\":\"$tenantUrl\", \"Email\":\"$emailAddress\", \"OrgKey\":\"$orgKey\"}" > "${NSINSTPARAM_JSON_FILE}"

    if [ $? == 0 ]
    then
        echo "$NSINSTPARAM_JSON_FILE created successfully"
        exit 0
    fi

    echo "Failed to create $NSINSTPARAM_JSON_FILE file"
    exit 1
fi

if [ $upnmode -eq 1 ]
then
    # Create the empty install param json file so that IDP mode will not trigger in case of any failure
    echo -n > "${NSINSTPARAM_JSON_FILE}"

    echo "Configuring NS Client installation by UPN"
    addonUrl="$4"
    echo "Addonman url is $addonUrl"

    if [[ $addonUrl != addon-* ]]; then
        echo "Addonman url does not start with addon-"
        exit 1
    fi

    orgkey="$5"

    upnMode="$6"

    echo "Total args " $#
    emailPrefFileProvided=0
    if [ $# -ge 7 ]
    then
        if [ `expr 6 + $optionalArgumentCnt` -le $# ]
        then
            # jamf always passes 11 arguments even if Admin passed less arguments.need to process empty argument
            declare -i emptyArgs=0
            declare -i i=$#-1
            while [ $i -ge 6 ] # first 6 args are compulsory in this use case
            do
                if [ "${argArray[$i]}" == "" ]
                then
                    emptyArgs+=1
                fi
                ((--i))
            done
        
            if [ `expr 6 + $optionalArgumentCnt + $emptyArgs` -lt $# ]
            then
                emailPrefFileProvided=1
            fi
        fi
    fi
    
    echo "emailPrefFileProvided : "$emailPrefFileProvided

    if [ $emailPrefFileProvided -eq 1 ]
    then
        emailPrefFile='/Library/Managed Preferences/'$7
        echo  "email pref file path $emailPrefFile"

        if [ ! -f "$emailPrefFile" ]
        then
            echo "$emailPrefFile not found, exiting installation process"
            exit 1
        fi

        upn=`defaults read "$emailPrefFile" email`
    else
        domainName=`echo show com.apple.opendirectoryd.ActiveDirectory | scutil | grep DomainNameFlat | awk '{print $3}'`
        if [ $? -ne 0 ]
        then
            echo "Failed to get domain name, exiting script"
        exit 1
        fi

        echo "Domain name is $domainName"

        counter=0
        while [ 1 ]
        do

            #
            # Get user Upn using dscl command.
            #

            upnAttr=`dscl /Active\ Directory/$domainName/All\ Domains -read /Users/$userName userPrincipalName`
            ret=$?

            if [ $ret -eq 0 ]
            then
                echo "Succeeded to fetch upn from AD error $ret."
            break
            fi

            counter=$((counter+1))

            if [ $counter -eq 5 ]
            then
                echo "Failed to fetch upn from AD error $ret after 5 attempts in every 5 seconds."
            exit 1
            fi

            sleep 5
            echo $counter: "Attempted to fetch upn"

        done


        echo "AD upn attribute: $upnAttr"
        #
        # Remove "dsAttrTypeNative:userPrincipalName:" part
        #
        upn=${upnAttr:36}
    fi

    echo "User upn: $upn"

    mkdir -p $TEMP_BRANDING_DIR

    ret=$?

    if [ $ret -ne 0 ]
    then
        echo "mkdir returns code $ret."
    fi

    echo "{\"AddonHostName\":\"$addonUrl\", \"Upn\":\"$upn\", \"OrgKey\":\"$orgkey\"}" > "${NSINSTPARAM_JSON_FILE}"

    echo "NS Client install param is copied at $NSINSTPARAM_JSON_FILE. Install should pickup this file and use for config download."
else
    # Create the empty install param json file so that IDP mode will not trigger in case of any failure
    echo -n > "${NSINSTPARAM_JSON_FILE}"

    echo "Configuring NS Client installation by Email"

    tenantUrl="$4"
    echo "Tenant url is $tenantUrl"

    domainName="$5"

    echo "Domain name is $domainName"

    orgKey="$6"

    counter=0
    while [ 1 ]
    do

        #
        # Get user email id using dscl command.
        #

        emailidAttr=`dscl /Active\ Directory/$domainName/All\ Domains -read /Users/$userName mail`
        ret=$?

        if [ $ret -eq 0 ]
        then
            echo "Succeeded to fetch email  from AD error $ret."
        break
        fi

        counter=$((counter+1))

        if [ $counter -eq 5 ]
        then
            echo "Failed to fetch email id from AD error $ret after 5 attempts in every 5 seconds."
        exit 1
        fi

        sleep 5
        echo $counter: "Attempted to fetch email id "

    done


    echo "AD email attribute: $emailidAttr"
    #
    # Remove "dsAttrTypeNative:mail: " part
    #
    emailId=${emailidAttr:23}
    echo "User email id: $emailId"

    mkdir -p $TEMP_BRANDING_DIR

    ret=$?

    if [ $ret -ne 0 ]
    then
        echo "mkdir returns code $ret."
    fi

    echo "{\"TenantHostName\":\"$tenantUrl\", \"Email\":\"$emailId\", \"OrgKey\":\"$orgKey\"}" > "${NSINSTPARAM_JSON_FILE}"

    echo "NS Client install param is copied at $NSINSTPARAM_JSON_FILE. Install should pickup this file and use for config download."
fi

exit 0
