#!/bin/bash

if [ "a$1" == "a" ]
then
  echo "usage $0 COPY_PATH"
  return 1
fi

COPY_PATH=$1
DOXY_OUTPUT_DIR="../DOXY_DOCS/html/."

# Exit if anything fails
set -e

# Authenticate user via Kerberos
kinit="/usr/bin/kinit"
if [ ! -x $kinit ]
then
  echo "ERROR: $kinit not found"
  exit 1
fi

kdestroy="/usr/bin/kdestroy"
if [ ! -x $kdestroy ]
then
  echo "ERROR: $kdestroy not found"
  exit 1
fi

# Validate input
: "${COPY_PATH:?COPY_PATH not provided}"
: "${EOS_ACCOUNT_USERNAME:?EOS_ACCOUNT_USERNAME not provided}"
: "${EOS_ACCOUNT_PASSWORD:?EOS_ACCOUNT_PASSWORD not provided}"

#build documentation
LAST_TAG=$( git describe --tags )
sed -i "s/<HOG_GIT_DESCRIBE>/\"$LAST_TAG\"/g" ./doxygen/Hog-doxygen.cfg
doxygen ./doxygen/Hog-doxygen.cfg  2>&1 >/dev/null
cp -r doxygen/mdFiles/figures $DOXY_OUTPUT_DIR

# Check the source directory exists
if [ ! -d "$DOXY_OUTPUT_DIR" ]
then
  echo "ERROR: Source directory '$DOXY_OUTPUT_DIR' doesn't exist"
  exit 1
fi

# EOS MGM URL, if not provided by the user
if [ -z "$EOS_MGM_URL" ];
then
  EOS_MGM_URL="root://eosuser.cern.ch"
fi

# Get credentials
echo "$EOS_ACCOUNT_PASSWORD" | $kinit "$EOS_ACCOUNT_USERNAME@CERN.CH" 2>&1 >/dev/null
if [ $? -ne 0 ]
then
  echo "Failed to get Krb5 credentials for '$EOS_ACCOUNT_USERNAME'"
  exit 1
fi

/usr/bin/xrdcp --force --recursive "$DOXY_OUTPUT_DIR" "$EOS_MGM_URL/$COPY_PATH/"

# Destroy credentials
$kdestroy
if [ $? -ne 0 ]
then
  echo "Krb5 credentials for '$EOS_ACCOUNT_USERNAME' have not been cleared up"
fi

exit 0

