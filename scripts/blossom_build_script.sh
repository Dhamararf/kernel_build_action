#!/usr/bin/env bash

# Dependencies
rm -rf kernel
git clone $REPO -b $BRANCH kernel
cd kernel

clang() {
    rm -rf clang
    echo "Cloning clang"
    if [ ! -d "clang" ]; then
        mkdir clang
        cd clang
        wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r383902.tar.gz
        tar -xvf *
        KBUILD_COMPILER_STRING="Another Clang"
        PATH="${PWD}/clang/bin:${PATH}"
    fi
    sudo apt install -y ccache
    echo "Done"
}

AnyKernel="https://github.com/Dhamararf/AnyKernel3.git"
AnyKernelbranch="master"

export IMG="$PWD"/out/arch/arm64/boot/Image.gz
export dtbo="$PWD"/out/arch/arm64/boot/dtbo.img
export dtb="$PWD"/out/arch/arm64/boot/dtb.img

DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
CACHE=1
export CACHE
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
KBUILD_BUILD_HOST="Ordinary-Being"
export KBUILD_BUILD_HOST
KBUILD_BUILD_USER="DhamarAr"
export KBUILD_BUILD_USER
DEVICE="Xiaomi Redmi 9C"
export DEVICE
CODENAME="blossom"
export CODENAME
DEFCONFIG_DEVICE="blossom_defconfig"
export DEFCONFIG_DEVICE
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=BETA
export STATUS
source "${HOME}"/.bashrc && source "${HOME}"/.profile
if [ $CACHE = 1 ]; then
    ccache -M 100G
    export USE_CCACHE=1
fi
LC_ALL=C
export LC_ALL

tg() {
    curl -sX POST https://api.telegram.org/bot"${token}"/sendMessage -d chat_id="${chat_id}" -d parse_mode=Markdown -d disable_web_page_preview=true -d text="$1" &>/dev/null
}

tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${token}"/sendDocument \
        -F "chat_id=${chat_id}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

sendinfo() {
    tg "
• Dham Action •
*Building on*: \`Github actions\`
*Date*: \`${DATE}\`
*Device*: \`${DEVICE} (${CODENAME})\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Last Commit*: [${COMMIT_HASH}](${REPO}/commit/${COMMIT_HASH})
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Build Status*: \`${STATUS}\`"
}

push() {
    cd AnyKernel || exit 1
    ZIP=$(echo *.zip)
    tgs "${ZIP}" "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | For *${DEVICE} (${CODENAME})* | ${KBUILD_COMPILER_STRING}"
}

tg_error() {
    curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
    -F chat_id="$2" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="$3Failed to build , check <code>error.log</code>"
}

tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
    -d "parse_mode=html" \
    -d text="$1"
}

tg_post_build() {
    MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)
    curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
    -F chat_id="$2" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="$3 build finished in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

compile() {
    if [ -d "out" ]; then
        rm -rf out && mkdir -p out
    fi

    make O=out ARCH="${ARCH}" "$DEFCONFIG_DEVICE"
    make -j$(nproc) \
        O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee error.log

    if [ -f "$IMG" ]; then
        echo -e "Build completed in $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds"
        echo -e "Cloning AnyKernel from your repo"
        git clone --depth=1 "$AnyKernel" --single-branch -b "$AnyKernelbranch" zip
        echo -e "Making kernel zip"
        cp -r "$IMG" zip/
        cp -r "$dtbo" zip/
        cp -r "$dtb" zip/
        cd zip
        export ZIP="test"-"kernel"-"$CODENAME"
        zip -r9 "$ZIP" * -x .git README.md LICENSE *placeholder
        curl -sLo zipsigner-3.0.jar https://gitlab.com/itsshashanksp/zipsigner/-/raw/master/bin/zipsigner-3.0-dexed.jar
        java -jar zipsigner-3.0.jar "$ZIP".zip "$ZIP"-signed.zip
        tg_post_msg "Kernel successfully compiled uploading ZIP" "$CHATID"
        tg_post_build "$ZIP"-signed.zip "$CHATID"
        tg_post_msg "done" "$CHATID"
        cd ..
        rm -rf error.log
        rm -rf out
        rm -rf zip
        rm -rf testing.log
        rm -rf zipsigner-3.0.jar
        exit
    else
        echo -e "Failed to compile the kernel, Check up to find the error"
        tg_post_msg "Kernel failed to compile uploading error log"
        tg_error "error.log" "$CHATID"
        rm -rf out
        rm -rf testing.log
        rm -rf error.log
        rm -rf zipsigner-3.0.jar
        exit 1
    fi
}

zipping() {
    cd AnyKernel || exit 1
    zip -r9 FulmenKernel-"${BRANCH}"-"${CODENAME}"-"${DATE}".zip ./*
    cd ..
}

clang
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$((END - START))
push
