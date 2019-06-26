#!/bin/bash

# SET ALL VERSIONS HERE
# NOTE - Check the patches below. If you update a version a patch might be unnecessary.

OPENSSL_VERSION=1.1.0i
BARESIP_VERSION=0.6.0
BARESIP_COMMIT=f667333cca7f5c3d86989755f8307a817fd6e0d5 # if set dist will not be downloaded
RE_VERSION=0.6.0
REM_VERSION=0.6.0
export OPUS_VERSION=1.3
export MIN_IOS_VERSION=9.0

# Download RE / REM / BARESIP (openssl and opus are downloaded in their respective sections below)

if [ "$BARESIP_COMMIT" = "" ]
then
wget -nc https://github.com/alfredh/baresip/releases/download/v$BARESIP_VERSION/baresip-$BARESIP_VERSION.tar.gz && tar -zxvf baresip-$BARESIP_VERSION.tar.gz && mv baresip-$BARESIP_VERSION ./baresip
else
git clone git@github.com:alfredh/baresip.git \
&& cd baresip \
&& git checkout $BARESIP_COMMIT \
&& cd .. \
&& rm -rf baresip/.git
fi

wget -nc https://github.com/creytiv/rem/releases/download/v$REM_VERSION/rem-$REM_VERSION.tar.gz && tar -zxvf rem-$REM_VERSION.tar.gz && mv rem-$REM_VERSION ./rem
wget -nc https://github.com/creytiv/re/releases/download/v$RE_VERSION/re-$RE_VERSION.tar.gz && tar -zxvf re-$RE_VERSION.tar.gz && mv re-$RE_VERSION ./re


# Apply patches

declare -a PATCH_LIBS=("baresip" "re" "rem")
for i in "${PATCH_LIBS[@]}"
do
    # Common patches
    for file in ../patches/${i}-*.patch
        do
        patch -d ${i} -p1 < "$file"
    done
    
    # Platform specific patches    
    for file in patches/${i}-*.patch
        do
        patch -d ${i} -p1 < "$file"
    done
done

# Clean previous output
rm -r distribution

# Declare libs to be copied
declare -a LIBS=("baresip" "re" "rem" "openssl" "opus")

# Create folder for finished libs
for i in "${LIBS[@]}"
    do
        mkdir -p distribution/${i}/include/
    done

### OPENSSL Begin

# Clone and build openssl
git clone git@github.com:x2on/OpenSSL-for-iPhone.git
cd OpenSSL-for-iPhone/
# We use a specific commit to be sure to use the same every time.
git reset --hard 10019638e80e8a8a5fc19642a840d8a69fac7349
# Will download and build openssl
export CONFIG_OPTIONS="no-ssl3 no-ssl2"
./build-libssl.sh --version=$OPENSSL_VERSION --deprecated --targets="ios-sim-cross-x86_64 ios-sim-cross-i386 ios64-cross-arm64 ios-cross-armv7s ios-cross-armv7"
cd ..

# Copy build artefacts for openssl and cleanup
mkdir -p openssl/include/openssl && \
mkdir -p openssl/lib && \
cp OpenSSL-for-iPhone/include/openssl/* openssl/include/openssl && \
cp OpenSSL-for-iPhone/lib/* openssl/lib/ && \
rm -rf OpenSSL-for-iPhone

### OPENSSL End

### OPUS Begin

# Build OPUS - Taken and modified from https://github.com/chrisballinger/Opus-iOS
# Will download and build opus
./build-libopus.sh

# Copy artefacts and clean up
mkdir opus && \
cp -r opus-build/dependencies/* opus && \
rm -r opus-build

### OPUS End

### BARESIP Begin

# Build Baresip
make clean
make contrib

### BARESIP End

# Copy artefacts
cp contrib/fat/lib/libbaresip.a distribution/baresip/
cp baresip/include/* distribution/baresip/include/

cp contrib/fat/lib/libre.a distribution/re/
cp -r re/include/* distribution/re/include/

cp contrib/fat/lib/librem.a distribution/rem/
cp rem/include/* distribution/rem/include/

cp openssl/lib/* distribution/openssl/
cp openssl/include/openssl/* distribution/openssl/include

cp opus/lib/libopus.a distribution/opus/
cp opus/include/opus/* distribution/opus/include/

# Remove the external libraries
for i in "${LIBS[@]}"
    do
        rm -rf ${i}
    done

rm -r contrib
rm -r build
rm *.tar.gz
