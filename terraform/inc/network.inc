<% if provider == "libvirt" %>

    resource "libvirt_network" "backend" {
        name      = "<%= cluster_prefix %>net"
        <% if exists?("net_mode") %>
        mode      = "<%= net_mode %>"
        <% else %>
        mode      = "nat"
        <% end %>

        domain    = "<%= cluster_prefix %>.local"
        addresses = ["10.17.3.0/24"]
    }

<% end %>
