#!/usr/bin/env bash

echo "This should take about 6 minutes to complete."
echo "The time is now: $(date +"%I:%M:%S")"
echo ""
echo "It will pause for quite a while at: Waiting for SSH to become available."
echo "This pause aligns with the OS being installed with the preseed, and provisioned."
echo ""
echo "It will also pause for a little while at a few compression steps, including: update-initramfs: Generating /boot/initrd.img-5.10.0-12-arm64."
echo ""
echo "This script only produces a Debian 11, ARM64, VMware Desktop box."
echo ""
echo "A debug flag for troubleshooting can be found in the packer hcl file."
echo ""
echo "This script will over-write an existing box in dist/"
read -p "Continue? [y/n]:" choice
case "$choice" in
    y|Y ) true;;
    n|N ) echo "aborting."; exit 0;;
    * ) echo "invalid input."; exit 1;;
esac

packer build -color=true -force bullseye-arm64.pkr.hcl

echo "Build is complete!"
exit 0;