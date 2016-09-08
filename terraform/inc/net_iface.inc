<% if provider == "libvirt" %>

    connection {
        type        = "ssh"
        user        = "root"

        <% if exists? "cloudinit" %>
            private_key = "${file("<%= ssh_key %>")}"
        <% else %>
            <%# the default for our images: user/pass=root/vagrant %>
            password = "vagrant"
        <% end %>
    }

    network_interface {
        <% if exists? "bridge" %>
            bridge     = "<%= bridge %>"
        <% else %>
            network_id = "${libvirt_network.backend.id}"
        <% end %>

        hostname       = "<%= hostname %>"
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
            floating_ip    = "${openstack_compute_floatingip_v2.fip_<%= floating_ip %>.address}"
            access_network = "true"
        <% end %>
    }

<% end %>
