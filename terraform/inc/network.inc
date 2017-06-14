<% if provider == "openstack" %>

    resource "openstack_compute_keypair_v2" "keypair" {
        name       = "<%= cluster_prefix %>_keypair"
        public_key = "${file("<%= ssh_key %>.pub")}"
    }

    resource "openstack_compute_secgroup_v2" "terraform" {
        name        = "<%= cluster_prefix %>_secgroup"
        description = "Security group for k8s via Terraform"

        # TODO: these rules are too weak...

        rule {
            from_port   = 22
            to_port     = 22
            ip_protocol = "tcp"
            cidr        = "0.0.0.0/0"
        }

        rule {
            from_port   = 80
            to_port     = 80
            ip_protocol = "tcp"
            cidr        = "0.0.0.0/0"
        }

        rule {
            from_port   = 443
            to_port     = 443
            ip_protocol = "tcp"
            cidr        = "0.0.0.0/0"
        }

        rule {
            from_port   = 8080
            to_port     = 8080
            ip_protocol = "tcp"
            cidr        = "0.0.0.0/0"
        }

        rule {
            from_port   = 6443
            to_port     = 6443
            ip_protocol = "tcp"
            cidr        = "0.0.0.0/0"
        }

        rule {
            from_port   = -1
            to_port     = -1
            ip_protocol = "icmp"
            cidr        = "0.0.0.0/0"
        }
    }

<% elsif provider == "libvirt" && !exists?("bridge") %>

    resource "libvirt_network" "backend" {
        name      = "<%= cluster_prefix %>net"

        <% if exists?("net_mode") %>
            mode      = "<%= net_mode %>"
        <% else %>
            mode      = "nat"
        <% end %>

        domain        = "<%= sane_cluster_domain_name %>"

        <% if exists?("net_cidr") %>
            addresses = ["<%= net_cidr %>"]
        <% else %>
            addresses = ["10.17.2.0/23"]
        <% end %>
    }

<% end %>
