#!/bin/sh -x

# non standard date pattern
NOW=$(date +"%y%m%d")
DAILY_RELEASE=${DAILY_RELEASE:-nuxeo-ep-5.2-${NOW}}

# download and start last packaged server
wget -r http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives/${DAILY_RELEASE}.zip || exit 1
unzip ${DAILY_RELEASE}.zip
mkdir output 2>/dev/null
rm -rf output/jboss 2>/dev/null
mv ${DAILY_RELEASE} output/jboss
rm -f nuxeo-ep*.zip
echo "BINDHOST=127.0.0.1" >output/jboss/bin/bind.conf

# Start jboss
output/jboss/bin/jbossctl start || exit 1
# Run functional tests
mkdir -p "$PWD/results/" 2>/dev/null
CMD="xvfb-run java -jar selenium/selenium-server.jar -port 14440 -timeout 7200 "
$CMD -htmlSuite "*firefox" http://127.0.0.1:8080/nuxeo/ "$PWD/selenium/tests/suite1.html" "$PWD/results/results1.html" || exit 1
ret1=$?
$CMD -htmlSuite "*firefox" http://127.0.0.1:8080/nuxeo/ "$PWD/selenium/tests/suite2.html" "$PWD/results/results2.html" || exit 1
ret2=$?
#stop nuxeo
output/jboss/bin/jbossctl stop

[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9
