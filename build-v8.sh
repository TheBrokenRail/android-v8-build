#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
printf 'tzdata tzdata/Areas select US\ntzdata tzdata/Zones/US select Detroit\n' | debconf-set-selections
apt-get update
apt-get install --yes git sudo curl python lsb-release
if [ ! -e v8-dir/.v8-repo-ready ]; then
    rm -rf v8-dir
fi
if [ ! -d v8-dir ]; then
    mkdir v8-dir
fi
cd v8-dir
if [ ! -e .v8-repo-ready ]; then
    if [ -d depot_tools ]; then
        rm -rf depot_tools
    fi
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi
export PATH=$PATH:$(pwd)/depot_tools
if [ ! -e .v8-repo-ready ]; then
    if [ -d v8 ]; then
        rm -rf v8
    fi
    gclient
    fetch v8
    cd v8
    git checkout -b 6.8 -t branch-heads/6.8
    echo 'y' | ./build/install-build-deps.sh
    echo "target_os = ['android']" >> ../.gclient
    gclient sync --nohooks
    cd ../
    touch .v8-repo-ready
fi
cd v8
if [ -d ../v8-libs ]; then
    rm -rf ../v8-libs
fi
mkdir ../v8-libs
cp -r include ../v8-libs
function build {
    if [ -d out.gn/$1.release ]; then
        rm -rf out.gn/$1.release
    fi
    ./tools/dev/v8gen.py $1.release
    GN_EDITOR='echo "No Editor!"' gn args out.gn/$1.release --args='target_os="android" target_cpu="'"$2"'" v8_target_cpu="'"$2"'" is_component_build=false v8_static_library=true v8_use_snapshot=false is_debug=false v8_enable_i18n_support=false v8_monolithic
=true'"$3"
    ninja -C out.gn/$1.release
    mkdir ../v8-libs/$1
    cp out.gn/$1.release/obj/libv8_monolith.a ../v8-libs/$1
}
echo '**** Building for ARM ****'
build arm arm ''
echo '**** Building for ARM64 ****'
build arm64 arm64 ''
echo '**** Building for x86 ****'
build ia32 x86 ''
echo '**** Building for x64 ****'
build x64 x64 ''
echo '**** Building for MIPSEL ****'
build mipsel mipsel ' mips_arch_variant="r2"'
