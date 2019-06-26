#!/bin/bash

# Download sources
make download-sources

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

make install-all

# Remove the external libraries
for i in "${LIBS[@]}"
    do
        rm -r ${i}
    done
