#!/bin/bash
#
# Public Link Creator Version 1.0
#
# (c) Copyright 2013 Bjoern Schiessle <bjoern@schiessle.org>
#
# This program is free software released under the MIT License, for more details
# see LICENSE.txt or http://opensource.org/licenses/MIT
#
# Description: 
#
# The program was developed for the Thunar file manager but it should also
# works with other file managers which provide similar possibilities to
# integrate shell scripts. For example I got some feedback that it also works
# nicely with Dolphin and Nautilus.
#
# This script can be integrated in the Thunar file manager as a "custom
# action". If you configure the "custom action" in Thunar, make sure to pass
# the paths of all selected files to the program using the "%F" parameter. The
# program expects the absolute path to the files. Once the custom action is
# configured you can execute the program from the right-click context menu. The
# program works for all file types and also for directories. Once the script
# gets executed it will first upload the files/directories to your ownCloud and
# afterwards it will generate a public link to access them. The link will be
# copied directly to your clipboard and a dialog will inform you about the
# URL. If you uploaded a single file or directory than the file/directory will
# be created directly below your "uploadTarget" as defined below. If you
# selected multiple files, than the programm will group them together in a
# directory named with the current timestamp.
#
# Before you can use the program you need to adjust at least the "baseURL",
# "username" and "password" config parameter below. If you keep "username"
# and/or "password" empty a dialog will show up and ask for the credentials.
#
# Requirements:
#
# - curl
# uploader.sh
# Giancarlo Birello <giancarlo.birello@gmail.com>
#




# config parameters
baseURL="https://ocloud.to.cnr.it"
uploadTarget=$1
localDir=$2
username=""
password=""
# if you use a self signed ssl cert you can specify here the path to your root
# certificate
cacert=""

# constants
TRUE=0
FALSE=1

webdavURL="$baseURL/remote.php/webdav"
url=$(echo "$webdavURL/$uploadTarget" | sed 's/\ /%20/g')

curlOpts=""
if [ -n "$cacert" ]; then
    curlOpts="$curlOpts --cacert $cacert"
fi

# check if base dir for file upload exists
baseDirNotFound() {
    if curl -u "$username":"$password" $curlOpts --silent --head --fail "$url"; then
        return $FALSE
    fi
    return $TRUE
}

checkCredentials() {
    curl -u "$username":"$password" $curlOpts --output /dev/null --silent --fail "$webdavURL"
    if [ $? != 0 ]; then
        echo "Username or password does not match"
        exit 1
    fi
}

# upload a directory recursively, first parameter contains the upload target
# and the second parameter contains the path to the local directory
uploadDirectory() {
    while read filePath; do
        filePath=$(basename "$filePath")
        urlencodedFilePath=$(echo "$filePath" | sed 's/\ /%20/g')
        if [ -d "$2/$filePath" ]; then
		  echo "Make Directory -> "$filePath
            curl -u "$username":"$password" $curlOpts -X MKCOL "$1/$urlencodedFilePath"
            uploadDirectory "$1/$urlencodedFilePath" "$2/$filePath"
        else
		  echo "Uploading ""$2/$filePath"
		  curl -u "$username":"$password" $curlOpts -T "$2/$filePath" "$1/$urlencodedFilePath"
        fi
    done < <(find "$2" -mindepth 1 -maxdepth 1)

}

# if no username/password is set in the script we ask the user to enter them
askForPassword() {
	read -p "Username:" username
	read -s -p "Password:" password
}

if [ -z $password ] || [ -z $username ]; then
    askForPassword
fi

checkCredentials

if baseDirNotFound; then
    echo "Remote base dir not found"
    exit 1
fi

filePath=$(basename "$localDir")
urlencodedFilePath=$(echo "$filePath" | sed 's/\ /%20/g')
curl -u "$username":"$password" $curlOpts -X MKCOL "$url/$urlencodedFilePath"
uploadDirectory "$url/$urlencodedFilePath" "$localDir"


exit
