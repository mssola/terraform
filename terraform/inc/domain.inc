<% if provider == "libvirt" && is_uefi_image %>

  firmware = "<%= firmware %>"

<% elsif provider == "openstack" %>

    <% if !exists? "flavor_name" %>
    flavor_name      = "m1.small"
    <% else %>
    flavor_name      = "<%= flavor_name %>"
    <% end %>
    key_pair         = "<%= key_pair %>"

<% end %>

  provisioner "file" {
    source      = "../bootstrap/salt"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "../bootstrap/grains/<%= grains_name %>"
    destination = "/tmp/salt/grains"
  }

  provisioner "remote-exec" {
    inline = [
      <% if exists?("salt_master") %>
      "echo \"master: <%= salt_master %> \" > /tmp/salt/minion.d/minion.conf",
      <% end %>
      <% if provider == "libvirt" %>
      "hostnamectl set-hostname <%= hostname %>.${libvirt_network.backend.domain}",
      <% end %>
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
