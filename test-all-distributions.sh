#!/bin/bash -x

PRODUCT=${PRODUCT:-dm}
SERVER=${SERVER:-jboss}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-5.4-build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}
SKIP_FUNKLOAD=${SKIP_FUNKLOAD:-}

# Cleaning
rm -rf ./jboss ./results ./download ./tomcat
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    link=`lynx --dump $LASTBUILD_URL | grep -o "http:.*archives\/nuxeo\-.*.zip\(.md5\)*" | sort -u |grep $PRODUCT-[0-9]|grep $SERVER|grep -v md5`
    wget -nv $link || exit 1
    ZIP_FILE=nuxeo-$PRODUCT*$SERVER.zip
fi
unzip -q $ZIP_FILE || exit 1
cd ..
build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./$SERVER || exit 1

# Update selenium tests
update_distribution_source
[ "$SERVER" = jboss ] && setup_jboss 127.0.0.1
[ "$SERVER" = tomcat ] && setup_tomcat 127.0.0.1

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# Use MySQL
if [ ! -z $MYSQL_HOST ]; then
    if [ "$SERVER" = tomcat ];
        echo ### ERROR: No MySQL template available for Tomcat! 
        exit 9
    fi
    setup_mysql_database
fi

# Use oracle
if [ ! -z $ORACLE_SID ]; then
    setup_oracle_database
fi

# Start Server
start_server 127.0.0.1

# Run selenium tests first
# it requires an empty db
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
HIDE_FF=true "$SELENIUM_PATH"/run.sh
ret1=$?

if [ -z $SKIP_FUNKLOAD ]; then
    java -version  2>&1 | grep 1.6.0
    if [ $? == 0 ]; then
        # FunkLoad tests works only with java 1.6.0 (j_ids are changed by java6)
        (cd "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/funkload; make EXT="--no-color")
        ret2=$?
    else
        ret2=0
    fi
else
    ret2=0
fi

# TODO: test nuxeo shell
#(cd "$NXDISTRIBUTION"/nuxeo-distribution-shell/ftest/; make)
ret3=0

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9
[ $ret3 -eq 0 ] || exit 9

# Upload successfully tested package and sources on http://www.nuxeo.org/static/snapshots/
UPLOAD_URL=${UPLOAD_URL:-}
SRC_URL=${SRC_URL:-download}
if [ ! -z "$UPLOAD_URL" ]; then
    date
    scp -C $SRC_URL/$ZIP_FILE $UPLOAD_URL || exit 1
    [ ! -z "$UPLOAD_SOURCES" ] && scp -C $SRC_URL/*sources*.zip $UPLOAD_URL
    date
fi
