resource "openstack_compute_floatingip_v2" "fip_kube_master" {
  pool = "floating"
}

output "kube-master-fip" {
  value = "${openstack_compute_floatingip_v2.fip_kube_master.address}"
}

resource "openstack_compute_instance_v2" "kube-master" {
  name        = "${var.cluster_prefix}kube-master"
  image_name  = "${var.openstack_image}"
  flavor_name = "m1.medium"
  key_pair    = "${var.key_pair}"

  network = {
    name           = "fixed"
    floating_ip    = "${openstack_compute_floatingip_v2.fip_kube_master.address}"
    access_network = "true"
  }

  depends_on = ["openstack_compute_instance_v2.salt"]

  provisioner "file" {
    source      = "../bootstrap/salt"
    destination = "/tmp"

    connection {
      private_key  = "${file("../ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }

  provisioner "file" {
    source      = "../bootstrap/grains/kube-master"
    destination = "/tmp/salt/grains"

    connection {
      private_key  = "${file("../ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: ${openstack_compute_instance_v2.salt.network.0.fixed_ip_v4}\" > /tmp/salt/minion.d/minion.conf ",
    ]

    connection {
      private_key  = "${file("../ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "bash /tmp/salt/provision-salt-minion.sh",
    ]

    connection {
      private_key  = "${file("../ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }
}
