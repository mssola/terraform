<% if provider == "openstack" %>

  resource "openstack_compute_floatingip_v2" "fip_<%= name %>" {
    pool = "floating"
  }

  output "fip_<%= name %>" {
    value = "${openstack_compute_floatingip_v2.fip_<%= name %>.address}"
  }

<% elsif provider == "libvirt" %>

  output "ip_<%= name %>" {
    value = "${libvirt_domain.<%= name %>.network_interface.0.addresses.0}"
  }

<% end %>
