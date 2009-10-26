#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

BUILD_URL=${BUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-5.3-build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}

# Cleaning
rm -rf ./tomcat ./results ./download
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $BUILD_URL | grep -o "http:.*nuxeo\-.*tomcat\.zip\(.md5\)*" | sort -u`

    # Download and unpack the lastest builds
    for link in $links; do
        wget -nv $link || exit 1
    done

    unzip -q nuxeo-*tomcat*.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..

# Tomcat tests --------------------------------------------------------

build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./tomcat || exit 1


# Update selenium tests
update_distribution_source


# Start tomcat
(cd tomcat/bin; chmod +x *.sh;  ./startup.sh) || exit 1

# TODO: replace hard coded sleep by updating the ctl script
sleep 60

# Run selenium tests first
# it requires an empty db
HIDE_FF=true "$NXDIR"/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/run.sh
ret1=$?

java -version  2>&1 | grep 1.5.0
if [ $? == 0 ]; then
    # FunkLoad tests works only with java 1.5.0 (j_ids are changed by java6)
    (cd "$NXDIR"/nuxeo-distribution/nuxeo-distribution-dm/ftest/funkload; make EXT="--no-color")
    ret2=$?
else
    ret2=0
fi

# Stop tomcat
(cd tomcat/bin; ./shutdown.sh)

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9


# Upload succesfully tested package on http://www.nuxeo.org/static/snapshots/
UPLOAD_URL=${UPLOAD_URL:-}
SRC_URL=${SRC_URL:download/*tomcat*}
if [ ! -z $UPLOAD_URL ]; then
    date
    scp $SRC_URL $UPLOAD_URL || exit 1
    date
fi