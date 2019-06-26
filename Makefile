# -------------------- VALUES TO CONFIGURE --------------------

# Path to your Android NDK (must be r19 or higher)
# Only tested with the one that is included in Android Sdk
NDK_PATH  :=  ~/Downloads/android-ndk-r20

# Android API level
API_LEVEL := 21

# Set default from following values: [armeabi-v7a, arm64-v8a]
ANDROID_TARGET_ARCH := arm64-v8a

# Directory where libraries and include files are instelled
OUTPUT_DIR := ./distribution

# -------------------- GENERATED VALUES --------------------

ifeq ($(ANDROID_TARGET_ARCH), armeabi-v7a)
	TARGET       := arm-linux-androideabi
	CLANG_TARGET := armv7a-linux-androideabi
	ARCH         := arm
	OPENSSL_ARCH := android-arm
	MARCH        := armv7-a
else
	TARGET       := aarch64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := arm
	OPENSSL_ARCH := android-arm64
	MARCH        := armv8-a
endif

PLATFORM	:= android-$(API_LEVEL)
OS		    := $(shell uname -s | tr "[A-Z]" "[a-z]")
HOST_OS		:= linux-x86_64

PWD		:= $(shell pwd)

# Toolchain and sysroot
TOOLCHAIN	:= $(NDK_PATH)/toolchains/llvm/prebuilt/linux-x86_64
SYSROOT		:= $(TOOLCHAIN)/sysroot
SYSROOT_INC     := $(NDK_PATH)/sysroot
PKG_CONFIG_LIBDIR := $(NDK_PATH)/prebuilt/linux-x86_64/lib/pkgconfig

# Toolchain tools
PATH	:= $(TOOLCHAIN)/bin:/usr/bin:/bin
AR	:= $(TARGET)-ar
AS	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CC	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CXX	:= $(CLANG_TARGET)$(API_LEVEL)-clang++
LD	:= $(TARGET)-ld
RANLIB	:= $(TARGET)-ranlib
STRIP	:= $(TARGET)-strip

# Compiler and Linker Flags for re, rem, and baresip
#
# NOTE: use -isystem to avoid warnings in system header files
COMMON_CFLAGS := -isystem $(SYSROOT_INC)/usr/include -fPIE -fPIC

CFLAGS := $(COMMON_CFLAGS) \
	-I$(PWD)/openssl/include \
	-I$(PWD)/opus/include_opus \
	-I$(PWD)/g7221/src \
	-I$(PWD)/spandsp/src \
	-I$(PWD)/tiff-3.8.2/libtiff \
	-I$(PWD)/ilbc \
	-I$(PWD)/webrtc/include \
	-I$(PWD)/zrtp/include \
	-I$(PWD)/zrtp/third_party/bnlib \
	-I$(PWD)/zrtp/third_party/bgaes \
	-march=$(MARCH)

LFLAGS := -L$(SYSROOT)/usr/lib/ \
	-L$(PWD)/openssl \
	-L$(PWD)/opus/.libs \
	-L$(PWD)/g7221/src/.libs \
	-L$(PWD)/spandsp/src/.libs \
	-L$(PWD)/ilbc \
	-L$(PWD)/zrtp \
	-L$(PWD)/zrtp/third_party/bnlib \
	-fPIE -pie

COMMON_FLAGS := \
	EXTRA_CFLAGS="$(CFLAGS) -DANDROID" \
	EXTRA_CXXFLAGS="$(CFLAGS) -DANDROID -DHAVE_PTHREAD" \
	EXTRA_LFLAGS="$(LFLAGS)" \
	SYSROOT=$(SYSROOT)/usr \
	HAVE_INTTYPES_H=1 \
	HAVE_GETOPT=1 \
	HAVE_LIBRESOLV= \
	HAVE_RESOLV= \
	HAVE_PTHREAD=1 \
	HAVE_PTHREAD_RWLOCK=1 \
	HAVE_LIBPTHREAD= \
	HAVE_INET_PTON=1 \
	HAVE_INET6=1 \
	HAVE_GETIFADDRS= \
	PEDANTIC= \
	OS=$(OS) \
	ARCH=$(ARCH) \
	USE_OPENSSL=yes \
	USE_OPENSSL_DTLS=yes \
	USE_OPENSSL_SRTP=yes \
	ANDROID=yes \
	RELEASE=1

OPENSSL_FLAGS := -D__ANDROID_API__=$(API_LEVEL)

EXTRA_MODULES := g711 opensles dtls_srtp opus

default:
	make libbaresip ANDROID_TARGET_ARCH=$(ANDROID_TARGET_ARCH)

.PHONY: openssl
openssl:
	-make distclean -C openssl
	cd openssl && \
	CC=clang ANDROID_NDK=$(NDK_PATH) PATH=$(PATH) ./Configure $(OPENSSL_ARCH) no-shared $(OPENSSL_FLAGS) && \
	CC=clang ANDROID_NDK=$(NDK_PATH) PATH=$(PATH) make build_libs

.PHONY: install-openssl
install-openssl: openssl
	rm -rf $(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)
	cp openssl/libcrypto.a \
		$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)
	cp openssl/libssl.a \
		$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)

.PHONY: opus
opus:
	$(NDK_PATH)/ndk-build APP_BUILD_SCRIPT=Android.mk NDK_PROJECT_PATH=opus APP_PLATFORM=android-21 && \
	cd opus && \
	rm -rf include_opus && \
	mkdir include_opus && \
	mkdir include_opus/opus && \
	cp include/* include_opus/opus

.PHONY: install-opus
install-opus: opus
	rm -rf $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)
	cp opus/obj/local/$(ANDROID_TARGET_ARCH)/libopus.a $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)

libre.a: Makefile
	make distclean -C re
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) make $@ -C re $(COMMON_FLAGS)

librem.a: Makefile libre.a
	make distclean -C rem
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) make $@ -C rem $(COMMON_FLAGS)

libbaresip: Makefile openssl opus librem.a libre.a
	make distclean -C baresip
	PKG_CONFIG_LIBDIR=$(PKG_CONFIG_LIBDIR) PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) CXX=$(CXX) \
	make libbaresip.a -C baresip $(COMMON_FLAGS) STATIC=1 LIBRE_SO=$(PWD)/re LIBREM_PATH=$(PWD)/rem MOD_AUTODETECT= BASIC_MODULES=no EXTRA_MODULES="$(EXTRA_MODULES)"

install-libbaresip: Makefile libbaresip
	rm -rf $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	cp re/libre.a $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	cp rem/librem.a $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	cp baresip/libbaresip.a $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/re/include
	mkdir -p $(OUTPUT_DIR)/re/include
	cp re/include/* $(OUTPUT_DIR)/re/include
	rm -rf $(OUTPUT_DIR)/rem/include
	mkdir $(OUTPUT_DIR)/rem/include
	cp rem/include/* $(OUTPUT_DIR)/rem/include
	rm -rf $(OUTPUT_DIR)/baresip/include
	mkdir $(OUTPUT_DIR)/baresip/include
	cp baresip/include/baresip.h $(OUTPUT_DIR)/baresip/include

install: install-openssl install-opus \
	install-libbaresip

install-all:
	make install ANDROID_TARGET_ARCH=armeabi-v7a
	make install ANDROID_TARGET_ARCH=arm64-v8a

.PHONY: download-sources
download-sources:
	rm -fr baresip re rem openssl opus*
	git clone https://github.com/alfredh/baresip.git
	git clone https://github.com/creytiv/rem.git
	git clone https://github.com/creytiv/re.git
	git clone https://github.com/openssl/openssl.git -b OpenSSL_1_1_1-stable --single-branch openssl
	wget http://downloads.xiph.org/releases/opus/opus-1.3.1.tar.gz
	tar zxf opus-1.3.1.tar.gz
	rm opus-1.3.1.tar.gz
	mv opus-1.3.1 opus
	patch -p0 < reg.c-patch

clean:
	make distclean -C baresip
	make distclean -C rem
	make distclean -C re
	-make distclean -C openssl
	-make distclean -C opus
