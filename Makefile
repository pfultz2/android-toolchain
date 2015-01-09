
JOBS := 8

PWD := $(shell pwd)
PREFIX := $(PWD)/usr
PKG_DIR := $(PWD)/pkg
ANDROID_SDK_ROOT := $(PWD)/android-sdk-linux
ANDROID_API_VERSION := android-14
ANDROID_NDK_TOOLCHAIN_VERSION := 4.9
JAVA_HOME := /usr/lib/jvm/java-6-openjdk-amd64/
PATH := $(PREFIX)/bin:$(ANDROID_SDK_ROOT)/tools:$(PATH)

.PHONY: all
all: qt boost

SDK_FILE := android-sdk_r24.0.2-linux.tgz
$(PKG_DIR)/download-sdk:
	cd $(PKG_DIR) && wget http://dl.google.com/android/$(SDK_FILE)
	tar -xf $(PKG_DIR)/$(SDK_FILE)
	touch $(PKG_DIR)/download-sdk

$(PKG_DIR)/sdk: $(PKG_DIR)/download-sdk
	echo "y" | android update sdk -u --filter $(ANDROID_API_VERSION)
	touch $(PKG_DIR)/sdk

NDK_REVISION := android-ndk-r10d
ANDROID_NDK_ROOT := $(PWD)/$(NDK_REVISION)
NDK_FILE := $(NDK_REVISION)-linux-x86_64.bin
$(PKG_DIR)/download-ndk:
	cd $(PKG_DIR) && wget http://dl.google.com/android/ndk/$(NDK_FILE)
	chmod 777 $(PKG_DIR)/$(NDK_FILE)
	$(PKG_DIR)/$(NDK_FILE)
	touch $(PKG_DIR)/download-ndk

$(PKG_DIR)/ndk: $(PKG_DIR)/download-ndk
	cd $(ANDROID_NDK_ROOT)/build/tools && \
	./make-standalone-toolchain.sh \
		--install-dir=$(PREFIX) \
		--platform=$(ANDROID_API_VERSION) \
		--toolchain=arm-linux-androideabi-$(ANDROID_NDK_TOOLCHAIN_VERSION) \
		--ndk-dir=$(ANDROID_NDK_ROOT) \
		--system=linux-x86_64
	touch $(PKG_DIR)/ndk

BOOST_VERSION := 55
BOOST_NAME := boost_1_$(BOOST_VERSION)_0
$(PKG_DIR)/download-boost:
	cd '$(PKG_DIR)' && wget http://downloads.sourceforge.net/project/boost/boost/1.$(BOOST_VERSION).0/$(BOOST_NAME).tar.bz2
	cd '$(PKG_DIR)' && tar --bzip2 -xf $(BOOST_NAME).tar.bz2
	cd '$(PKG_DIR)/$(BOOST_NAME)' && patch -p1 < $(PWD)/boost/$(BOOST_NAME).patch
	find '$(PKG_DIR)/$(BOOST_NAME)' -type f | xargs -n1 -P $(JOBS) sed -i "s/-lrt//g"
	cp '$(PWD)/boost/user.hpp' '$(PKG_DIR)/$(BOOST_NAME)/boost/config/user.hpp'
	touch '$(PKG_DIR)/download-boost'

$(PKG_DIR)/boost: $(PKG_DIR)/download-boost $(PKG_DIR)/ndk
	cd '$(PKG_DIR)/$(BOOST_NAME)' && ./bootstrap.sh
	cd '$(PKG_DIR)/$(BOOST_NAME)' && ./b2 -a -q -j $(JOBS) \
		--ignore-site-config \
		--user-config=$(PWD)/boost/user-config.jam \
		address-model=32 \
		architecture=arm \
		link=static,shared \
		threading=multi \
		toolset=gcc-android \
		target-os=linux \
		--disable-icu \
		--without-atomic \
		--without-context \
		--without-coroutine \
		--without-log \
		--without-mpi \
		--without-python \
		--without-serialization \
		--without-system \
		-sNO_BZIP2=1
		--prefix='$(PREFIX)' \
		--exec-prefix='$(PREFIX)/bin' \
		--libdir='$(PREFIX)/lib' \
		--includedir='$(PREFIX)/include' \
		cxxflags='-std=c++1y' \
		install
	touch '$(PKG_DIR)/boost'

.PHONY: boost
boost: $(PKG_DIR)/boost

wget http://download.qt-project.org/official_releases/qt/5.4/5.4.0/single/qt-everywhere-opensource-src-5.4.0.tar.gz
QT_NAME := qt-everywhere-opensource-src-5.4.0
$(PKG_DIR)/download-qt:
	cd $(PKG_DIR) && wget http://download.qt-project.org/official_releases/qt/5.4/5.4.0/single/$(QT_NAME).tar.gz
	cd $(PKG_DIR) && tar -xf $(QT_NAME).tar.gz
	touch $(PKG_DIR)/download-qt

$(PKG_DIR)/qt: $(PKG_DIR)/download-qt $(PKG_DIR)/ndk $(PKG_DIR)/sdk
	cd $(PKG_DIR)/$(QT_NAME)/ && ./configure \
		-release \
		-c++11 \
		-optimized-qmake \
		-prefix '$(PREFIX)' \
		-xplatform android-g++ \
		-nomake tests \
		-nomake examples \
		-android-ndk '$(ANDROID_NDK_ROOT)' \
		-android-sdk '$(ANDROID_SDK_ROOT)' \
		-android-ndk-host linux-x86_64 \
		-android-toolchain-version $(ANDROID_NDK_TOOLCHAIN_VERSION) \
		-skip qttranslations \
		-skip qtwebkit \
		-skip qtserialport \
		-skip qtwebkit-examples \
		-no-warnings-are-errors \
		-opensource \
		-confirm-license && \
	make -j $(JOBS) && \
	make install
	touch $(PKG_DIR)/qt

.PHONY: qt
qt: $(PKG_DIR)/qt

