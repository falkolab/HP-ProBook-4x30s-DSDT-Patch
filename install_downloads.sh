#!/bin/bash

#set -x

SUDO=sudo
#SUDO='echo #'
#SUDO=nothing
TAG=tag_file
TAGCMD=`pwd`/tools/tag
SLE=/System/Library/Extensions
LE=/Library/Extensions
EXCEPTIONS="Sensors|FakePCIID_BCM57XX|FakePCIID_AR9280|FakePCIID_Intel_GbX|BrcmPatchRAM|BrcmBluetoothInjector|BrcmFirmwareData|BrcmNonPatchRAM|USBInjectAll|Lilu|IntelGraphicsFixup"
ESSENTIAL="FakeSMC.kext SATA-100-series-unsupported.kext IntelMausiEthernet.kext RealtekRTL8111.kext USBInjectAll.kext Lilu.kext IntelGraphicsFixup.kext AppleBacklightInjector.kext IntelBacklight.kext VoodooPS2Controller.kext"

# extract minor version (eg. 10.9 vs. 10.10 vs. 10.11)
MINOR_VER=$([[ "$(sw_vers -productVersion)" =~ [0-9]+\.([0-9]+) ]] && echo ${BASH_REMATCH[1]})

# install to /Library/Extensions for 10.11 or greater
if [[ $MINOR_VER -ge 11 ]]; then
    KEXTDEST=$LE
else
    KEXTDEST=$SLE
fi

# this could be removed if 'tag' can be made to work on old systems
function tag_file
{
    if [[ $MINOR_VER -ge 9 ]]; then
        $SUDO "$TAGCMD" "$@"
    fi
}

function check_directory
{
    for x in $1; do
        if [ -e "$x" ]; then
            return 1
        else
            return 0
        fi
    done
}

function nothing
{
    :
}

function install_kext
{
    if [ "$1" != "" ]; then
        echo installing $1 to $KEXTDEST
        $SUDO rm -Rf $SLE/`basename $1` $KEXTDEST/`basename $1`
        $SUDO cp -Rf $1 $KEXTDEST
        $TAG -a Gray $KEXTDEST/`basename $1`
    fi
}

function install_app
{
    if [ "$1" != "" ]; then
        echo installing $1 to /Applications
        $SUDO rm -Rf /Applications/`basename $1`
        $SUDO cp -Rf $1 /Applications
        $TAG -a Gray /Applications/`basename $1`
    fi
}

function install_binary
{
    if [ "$1" != "" ]; then
        echo installing $1 to /usr/bin
        $SUDO rm -f /usr/bin/`basename $1`
        $SUDO cp -f $1 /usr/bin
        $TAG -a Gray /usr/bin/`basename $1`
    fi
}

function install
{
    installed=0
    out=${1/.zip/}
    rm -Rf $out/* && unzip -q -d $out $1
    check_directory $out/Release/*.kext
    if [ $? -ne 0 ]; then
        for kext in $out/Release/*.kext; do
            # install the kext when it exists regardless of filter
            kextname="`basename $kext`"
            if [[ -e "$SLE/$kextname" || -e "$KEXTDEST/$kextname" || "$2" == "" || "`echo $kextname | grep -vE "$2"`" != "" ]]; then
                install_kext $kext
            fi
        done
        installed=1
    fi
    check_directory $out/*.kext
    if [ $? -ne 0 ]; then
        for kext in $out/*.kext; do
            # install the kext when it exists regardless of filter
            kextname="`basename $kext`"
            if [[ -e "$SLE/$kextname" || -e "$KEXTDEST/$kextname" || "$2" == "" || "`echo $kextname | grep -vE "$2"`" != "" ]]; then
                install_kext $kext
            fi
        done
        installed=1
    fi
    check_directory $out/Release/*.app
    if [ $? -ne 0 ]; then
        for app in $out/Release/*.app; do
            install_app $app
        done
        installed=1
    fi
    check_directory $out/*.app
    if [ $? -ne 0 ]; then
        for app in $out/*.app; do
            install_app $app
        done
        installed=1
    fi
    if [ $installed -eq 0 ]; then
        check_directory $out/*
        if [ $? -ne 0 ]; then
            for tool in $out/*; do
                install_binary $tool
            done
        fi
    fi
}

if [ "$(id -u)" != "0" ]; then
    echo "This script requires superuser access..."
fi

# unzip/install tools
check_directory ./downloads/tools/*.zip
if [ $? -ne 0 ]; then
    echo Installing tools...
    cd ./downloads/tools
    for tool in *.zip; do
        install $tool
    done
    cd ../..
fi

if [ "$1" != "toolsonly" ]; then

# unzip/install kexts
check_directory ./downloads/kexts/*.zip
if [ $? -ne 0 ]; then
    echo Installing kexts...
    cd ./downloads/kexts
    for kext in *.zip; do
        install $kext "$EXCEPTIONS"
    done
    if [[ $MINOR_VER -ge 11 ]]; then
        # 10.11 needs BrcmPatchRAM2.kext
        cd RehabMan-BrcmPatchRAM*/Release && install_kext BrcmPatchRAM2.kext && cd ../..
        cd RehabMan-BrcmPatchRAM*/Release && install_kext BrcmNonPatchRAM2.kext && cd ../..
        # 10.11 needs USBInjectAll.kext
        cd RehabMan-USBInjectAll*/Release && install_kext USBInjectAll.kext && cd ../..
        # remove BrcPatchRAM.kext just in case
        $SUDO rm -Rf $SLE/BrcmPatchRAM.kext $KEXTDEST/BrcmPatchRAM.kext
        # remove injector just in case
        $SUDO rm -Rf $SLE/BrcmBluetoothInjector.kext $KEXTDEST/BrcmBluetoothInjector.kext
    else
        # prior to 10.11, need BrcmPatchRAM.kext
        cd RehabMan-BrcmPatchRAM*/Release && install_kext BrcmPatchRAM.kext && cd ../..
        cd RehabMan-BrcmPatchRAM*/Release && install_kext BrcmNonPatchRAM.kext && cd ../..
        # remove BrcPatchRAM2.kext just in case
        $SUDO rm -Rf $SLE/BrcmPatchRAM2.kext $KEXTDEST/BrcmPatchRAM2.kext
        # remove injector just in case
        $SUDO rm -Rf $SLE/BrcmBluetoothInjector.kext $KEXTDEST/BrcmBluetoothInjector.kext
    fi
    if [[ $MINOR_VER -ge 12 ]]; then
        #10.12 needs Lilu.kext and IntelGraphicsFixup.kext
        cd RehabMan-Lilu*/Release && install_kext Lilu.kext && cd ../..
        cd RehabMan-IntelGraphicsFixup*/Release && install_kext IntelGraphicsFixup.kext && cd ../..
    fi
    # this guide does not use BrcmFirmwareData.kext
    $SUDO rm -Rf $SLE/BrcmFirmwareData.kext $KEXTDEST/BrcmFirmwareData.kext
    # now using IntelBacklight.kext instead of ACPIBacklight.kext
    $SUDO rm -Rf $SLE/ACPIBacklight.kext $KEXTDEST/ACPIBacklight.kext
    # deal with some renames
    if [[ -e $KEXTDEST/FakePCIID_Broadcom_WiFi.kext ]]; then
        # remove old FakePCIID_BCM94352Z_as_BCM94360CS2.kext
        $SUDO rm -Rf $SLE/FakePCIID_BCM94352Z_as_BCM94360CS2.kext $KEXTDEST/FakePCIID_BCM94352Z_as_BCM94360CS2.kext
    fi
    if [[ -e $KEXTDEST/FakePCIID_Intel_HD_Graphics.kext ]]; then
        # remove old FakePCIID_HD4600_HD4400.kext
        $SUDO rm -Rf $SLE/FakePCIID_HD4600_HD4400.kext $KEXTDEST/FakePCIID_HD4600_HD4400.kext
    fi
    cd ../..
fi

# remove kexts that PBI might have installed
if [[ -e $SLE/AppleHDAIDT.kext ]]; then
    $SUDO rm -Rf $SLE/AppleHDAIDT.kext
fi
if [[ -e $SLE/AppleHDAALC.kext ]]; then
    $SUDO rm -Rf $SLE/AppleHDAALC.kext
fi
if [[ -e $SLE/USBXHCI_4x40s.kext ]]; then
    $SUDO rm -Rf $SLE/USBXHCI_4x40s.kext
fi

# install (injector) kexts in the repo itself
# patching AppleHDA
HDA=ProBook
$SUDO rm -Rf $KEXTDEST/AppleHDA_$HDA.kext $SLE/AppleHDA_$HDA.kext
$SUDO rm -Rf $KEXTDEST/AppleHDAHCD_$HDA.kext $SLE/AppleHDAHCD_$HDA.kext
$SUDO rm -f $SLE/AppleHDA.kext/Contents/Resources/*.zml*
if [[ ! -e AppleHDA_$HDA.kext ]]; then
    ./patch_hda.sh $HDA
fi
if [[ $MINOR_VER -le 9 ]]; then
    # dummyHDA configuration
    install_kext AppleHDA_$HDA.kext
else
    # alternate configuration (requires .xml.zlib .zml.zlib AppleHDA patch)
    #install_kext AppleHDAHCD_$HDA.kext
    $SUDO cp AppleHDA_${HDA}_Resources/*.zml* $SLE/AppleHDA.kext/Contents/Resources
    $TAG -a Gray $SLE/AppleHDA.kext
fi

# install NVMeGeneric.kext if it is found in Clover/kexts
# patch it so it is marked OSBundleRequired=Root
EFI=`./mount_efi.sh`
if [[ -e "$EFI/EFI/CLOVER/kexts/Other/NVMeGeneric.kext" ]]; then
    cp -Rf "$EFI/EFI/CLOVER/kexts/Other/NVMeGeneric.kext" /tmp/NVMeGeneric.kext
    /usr/libexec/PlistBuddy -c "Add :OSBundleRequired string" /tmp/NVMeGeneric.kext/Contents/Info.plist
    /usr/libexec/PlistBuddy -c "Set :OSBundleRequired Root" /tmp/NVMeGeneric.kext/Contents/Info.plist
    install_kext /tmp/NVMeGeneric.kext
fi
# install HackrNVMEFamily-.* if it is found in Clover/kexts
kext=`echo "$EFI"/EFI/CLOVER/kexts/Other/HackrNVMeFamily-*.kext`
if [[ -e "$kext" ]]; then
    install_kext "$kext"
fi

# install kexts for JMicron card reader and supported Atheros WiFi
cd kexts
install_kext SATA-100-series-unsupported.kext
install_kext HSSDBlockStorage.kext
install_kext JMB38X.kext
install_kext JMicronATA.kext
install_kext ProBookAtheros.kext
cd ..

# and AppleBacklightInjector.kext
#  (set BKLT=1 in SSDT-HACK.dsl to use it, set BKLT=0 to use IntelBacklight.kext)
if [[ $MINOR_VER -ge 12 ]]; then
    cd kexts
    install_kext AppleBacklightInjector.kext
    cd ..
    # remove IntelBacklight.kext if it is installed (doesn't work with 10.12)
    if [ -d $KEXTDEST/IntelBacklight.kext ]; then
        $SUDO rm -Rf $KEXTDEST/IntelBacklight.kext
    fi
fi

#check_directory *.kext
#if [ $? -ne 0 ]; then
#    for kext in *.kext; do
#        install_kext $kext
#    done
#fi

# force cache rebuild with output
$SUDO touch $SLE && $SUDO kextcache -u /

# install VoodooPS2Daemon
echo Installing VoodooPS2Daemon to /usr/bin and /Library/LaunchDaemons...
cd ./downloads/kexts/RehabMan-Voodoo-*
$SUDO cp ./Release/VoodooPS2Daemon /usr/bin
$TAG -a Gray /usr/bin/VoodooPS2Daemon
$SUDO cp ./org.rehabman.voodoo.driver.Daemon.plist /Library/LaunchDaemons
$TAG -a Gray /Library/LaunchDaemons/org.rehabman.voodoo.driver.Daemon.plist
cd ../../..

# install HPFanReset.efi
EFI=`./mount_efi.sh`
cd downloads/efi
zip=`echo -n HPFanReset*.zip`
out=${zip/.efi.zip/}
rm -Rf $out && unzip -q -d $out $zip
echo Installing HPFanReset.efi to $EFI/EFI/CLOVER/drivers64UEFI
cp $out/*.efi $EFI/EFI/CLOVER/drivers64UEFI
cd ../..

# install/update kexts on EFI/Clover/kexts/Other
EFI=`./mount_efi.sh`
echo Updating kexts at EFI/Clover/kexts/Other
for kext in $ESSENTIAL; do
    if [[ -e $KEXTDEST/$kext ]]; then
        echo updating $EFI/EFI/CLOVER/kexts/Other/$kext
        cp -Rf $KEXTDEST/$kext $EFI/EFI/CLOVER/kexts/Other
    fi
done

fi # "toolsonly"

