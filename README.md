# Cross compilation of Baresip

This repo contains the scripts needed to compile baresip for use on Android and iOS.

## Android

### Prerequisites

* A 64-bit Linux dist, tested with VirtualBox running Ubuntu 64-bit ([VirtualBox](https://www.virtualbox.org/wiki/Downloads), [Ubuntu](https://ubuntu.com/download/desktop/thank-you?country=SE&version=18.04.2&architecture=amd64))
  When creating your Ubuntu image make sure to create a virtual disc with at least 15GB of storage.

* Android NDK, for example r20
`android-ndk-r20-linux` will work and can be downloaded from [here](https://developer.android.com/ndk/downloads).

  Once installed you need to point it out by updating `NDK_PATH` in `android/Makefile`.

  ```
  NDK_PATH  := ~/Downloads/android-ndk-r20
  ```

### Compiling

Baresip is build from the `android` directory.

```
./generate_dist.sh

```
Output can be found in the `distribution` folder after the script has finished executing.

### Customization

Update versions for external libraries directly in the `generate_dist.sh` file.

## iOS

### Prerequisites

* An installation of Xcode.
* You need to install `wget`, for instance using `brew install wget`.

### Compiling

Baresip is build from the `ios` directory.

```
./generate_dist.sh

```
Output can be found in the `distribution` folder after the script has finished executing.

### Customization

Update versions for external libraries as well as min iOS version directly in the `generate_dist.sh` file.

## General contribution guidelines

If changes to source is needed for compilation to succeed, represent those changes in .patch files that are applied before compilation.
Always use locked versions, not latest, since this will change over time.

## Creating a new patch

Easiest way is to clone the original repo and create a branch for your patches. Make sure you use the tag or commit that the cross-compile script is setup with.
Apply any other patches with `patch -p1 < <file>` first so you know your changes are applied correctly. Have a look in `generate_dist.sh` to check what patches are applied.

Make your changes in the branch, commit it, then create a patch file from the commit:
```
git format-patch -k --stdout HEAD^ > library-xx-my-patch.patch
```

### Naming

`library-xx-my-patch.patch`

`library` should be `re`, `rem` or `baresip` and the `xx` should be the patch sequential number. Check the destination patches dir for present patches (see checklist) and if the last one has sequence `02`, you should make your patch `03`.
This is so that patches are applied in the right sequence.  

### Checklist

* Put the patch file in the right directory. If for both ios/android, put it in the root `patches` directory, otherwise put it in `ios/patches` or `android/patches`.
* Update the `README` in the patches dir with details about your patch.
* Test a clean compile and make sure it works in the SDK. (`generate_dist.sh` should pick up the patch file automatically as part of execution if you followed naming and dir conventions.)
