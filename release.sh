#!/usr/bin/env bash
# This script (for macOS) will release Dependency-Track

read -p "Are you sure you want to release (yes/no)? "
if ( [ "$REPLY" == "yes" ] ) then


export JAVA_HOME=`/usr/libexec/java_home -v 1.8`
export PATH=JAVA_HOME/bin:$PATH


# Retrieves the current version from the pom. This will likely be in the format: x.x.x-SNAPSHOT
CURRENT_VERSION=$(cat pom.xml | grep "^    <version>.*</version>$" | awk -F'[><]' '{print $3}')
# Define and remove the -SNAPSHOT suffix from CURRENT_VERSION and assign the result to RELEASE_VERSION
suffix="-SNAPSHOT";
RELEASE_VERSION=${CURRENT_VERSION%$suffix};
# Increment RELEASE_VERSION by one. This should result in: x.x.x -> x.x.x+1
NEXT_VERSION=$(echo $RELEASE_VERSION | awk -F. -v OFS=. 'NF==1{print ++$NF}; NF>1{if(length($NF+1)>length($NF))$(NF-1)++; $NF=sprintf("%0*d", length($NF), ($NF+1)%(10^length($NF))); print}')
# Defines the next SNAPSHOT release version
NEXT_SNAPSHOT_VERSION=$NEXT_VERSION-SNAPSHOT


# Updates the version, commits, builds the war and executable war, and releases those two artifacts to GitHub
mvn versions:set -DnewVersion=$RELEASE_VERSION
if [ -d ".git" ]; then
    git commit -m "Preparing to release $RELEASE_VERSION"
    git push origin HEAD
elif [ -d ".svn" ]; then
    svn commit -m "Preparing to release $RELEASE_VERSION"
fi
mvn clean package
mvn package -Dmaven.test.skip=true -P embedded-jetty -Dlogback.configuration.file=src/main/docker/logback.xml
mvn net.nicoulaj.maven.plugins:checksum-maven-plugin:files
mvn github-release:release


# Cleanup containers/images, build new image and push to Docker Hub
REPO=owasp/dependency-track
docker rm dependency-track
docker rmi $REPO:latest
docker rmi $REPO:$RELEASE_VERSION
docker build -f src/main/docker/Dockerfile -t $REPO:$RELEASE_VERSION -t $REPO:latest .
docker login
docker push $REPO


# Version bump to prepare next snapshot
mvn versions:set -DnewVersion=$NEXT_SNAPSHOT_VERSION
if [ -d ".git" ]; then
    git commit -m "Prepare for next development iteration: $NEXT_SNAPSHOT_VERSION"
    git push origin HEAD
elif [ -d ".svn" ]; then
    svn commit -m "Prepare for next development iteration: $NEXT_SNAPSHOT_VERSION"
fi


else
  echo 'Exit without release'
fi