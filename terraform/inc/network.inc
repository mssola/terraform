<% if provider == "libvirt" && !exists?("bridge")%>

    resource "libvirt_network" "backend" {
        name      = "<%= cluster_prefix %>net"

        <% if exists?("net_mode") %>
        mode      = "<%= net_mode %>"
        <% else %>
        mode      = "nat"
        <% end %>

        domain    = "<%= cluster_prefix %>.local"

        <% if exists?("net_cidr") %>
        addresses = ["<%= net_cidr %>"]
        <% else %>
        addresses = ["10.17.3.0/24"]
        <% end %>
    }

<% end %>
