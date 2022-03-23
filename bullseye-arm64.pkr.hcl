packer {
    /*
        Note: Packer version 1.5.0 introduced support for HCL2 templates as a beta feature. As of version 1.7.0, HCL2 support is no longer in beta and is the preferred way to write Packer configuration(s).
    */
    required_version = ">= 1.8.0"
}

variables {
    debug = false
}

locals {
    _boot_command     = [
        "<esc><esc><esc>e<wait>",
        "<down><down><down><end>",
        "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>", /* remove " --- quiet" */
        "auto=true ",
        "lowmem/low=true ",
        /* HACK: set the hostname and domain name in advance of the preseed because by the time it happens, the apropriate preseed directives are not honored */
        "hostname=vagrant ",
        "domain=local ",
        "preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg ",
        "<wait><f10>"
    ]
    _headless         = "${!var.debug}"
    _vm_name          = "bullseye-arm64-${formatdate("YYYYMMDDhhmmss", timestamp())}"
    _iso_urls         = [
        "${abspath(path.root)}/cache/debian-11.2.0-arm64-netinst.iso",
        "https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-11.2.0-arm64-netinst.iso",
        "http://cdimage.debian.org/cdimage/archive/11.2.0/arm64/iso-cd/debian-11.2.0-arm64-netinst.iso",
    ]
    _preseed_file     = "${abspath(path.root)}/preseed.cfg"
    _vagrantfile      = "${abspath(path.root)}/Vagrantfile"
    _output           = "${abspath(path.root)}/dist/providers/{{.Provider}}/bullseye-arm64.box"
    _output_directory = "${abspath(path.root)}/dist/sandbox"
}

source "vmware-iso" "bullseye-arm64" {
    boot_command         = "${local._boot_command}"
    boot_wait            = "3s"
    cores                = 1
    cpus                 = 1
    disk_size            = 8192
    disk_type_id         = "0"
    guest_os_type        = "arm-debian11-64"
    headless             = "${local._headless}"
    http_content         = {
        "/preseed.cfg" = file(local._preseed_file)
    }
    iso_checksum         = "file:https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/SHA256SUMS"
    iso_target_path      = "${abspath(path.root)}/cache/debian-11.2.0-arm64-netinst.iso"
    iso_urls             = "${local._iso_urls}"
    memory               = 1024
    network              = "nat"
    network_adapter_type = "e1000"
    output_directory     = "${local._output_directory}"
    shutdown_command     = "echo 'vagrant' | sudo -S /sbin/shutdown -hP now"
    sound                = false
    ssh_password         = "vagrant"
    ssh_port             = 22
    ssh_username         = "vagrant"
    ssh_wait_timeout     = "3600s"
    usb                  = false
    vm_name              = "${local._vm_name}"
    vmdk_name            = "${local._vm_name}"
    vmx_data = {
        "ehci.pciSlotNumber" = "34"
        "ehci.present" = "TRUE"
        "ethernet0.pciSlotNumber" = "32"
        "floppy0.present"   = "FALSE"

        // Fixes Transport (vmdb) error -14: Pipe connection has been broken
        "virtualhw.version" = "19"

        // usb is required to be able to type the boot command over VNC
        // even though packer issues a warning, it should be ignored by the user
        "usb:1.deviceType" = "hub"
        "usb:1.parent" = "-1"
        "usb:1.port" = "1"
        "usb:1.present" = "TRUE"
        "usb:1.speed" = "2"
        "usb.pciSlotNumber" = "32"
        "usb.present" = "TRUE"
    }
    vmx_remove_ethernet_interfaces = "true"

    // Fixes: The device type "lsilogic" specified for "scsi0" is not supporte by VMware Fusion e.x.p.
    disk_adapter_type = "nvme"

    fusion_app_path = "/Applications/VMware Fusion Tech Preview.app/"
}

build {
    sources = [
        "source.vmware-iso.bullseye-arm64"
    ]

    provisioner "shell" {
        script          = "provision.sh"
        execute_command = "chmod +x '{{.Path}}'; sudo -S env {{.Vars}} '{{.Path}}'"
    }

    post-processor "vagrant" {
        compression_level              = 9
        keep_input_artifact            = false
        output                         = "${local._output}/dist/{{.Provider}}/{{.BuildName}}.box"
        vagrantfile_template           =  "${local._vagrantfile}"
        vagrantfile_template_generated = true
    }
}
