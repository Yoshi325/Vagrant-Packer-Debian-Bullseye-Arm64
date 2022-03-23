Vagrant Packer Debian Bullseye ARM64
====================================

This project is intentionally narrow in what it provides. It will use `Packer by Hashcorp <https://www.packer.io>`_ to create a Vagrant box with Debian 11.2 (Bullseye) for ARM64 (to run on, for example, Apple's new M1 machines). And to run on the VMware Desktop provider. It does this using the new HCL syntax (instead of the legacy JSON syntax). Also, it uses :code:`open-vm-tools` instead of VMware's Tools.

Run :code:`./build.sh` to generate the box.