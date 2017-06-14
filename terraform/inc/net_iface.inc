<% if provider == "libvirt" %>

    connection {
        type        = "ssh"
        user        = "root"
        private_key = "${file("<%= ssh_key %>")}"
    }

    network_interface {
        <% if exists? "bridge" %>
            bridge     = "<%= bridge %>"
        <% else %>
            network_id = "${libvirt_network.backend.id}"
        <% end %>

        hostname       = "<%= hostname %>"
        <% if !exists?("net_cidr") %>
            addresses      = ["10.17.3.${count.index}"]
        <% end %>
        wait_for_lease = 1
    }

<% elsif provider == "openstack" %>

    connection {
        private_key      = "${file("<%= ssh_key %>")}"

        <% if exists? "bastion" %>
            bastion_host = "${openstack_compute_floatingip_v2.fip_<%= bastion %>.address}"
        <% end %>
    }

    network = {
        name               = "fixed"

        <% if exists? "floating_ip" %>
            <% if exists? "count" %>
                floating_ip = "${element(openstack_compute_floatingip_v2.fip_<%= floating_ip %>.*.address, count.index)}"
            <% else %>
                floating_ip    = "${openstack_compute_floatingip_v2.fip_<%= floating_ip %>.address}"
            <% end %>
            access_network = "true"
        <% end %>
    }

<% end %>
