<% if provider == "libvirt" && is_uefi_image %>

  firmware = "<%= firmware %>"

<% elsif provider == "openstack" %>

    <% if !exists? "flavor_name" %>
    flavor_name      = "m1.small"
    <% else %>
    flavor_name      = "<%= flavor_name %>"
    <% end %>
    key_pair         = "<%= key_pair %>"

    security_groups = [
        "default",
        "${openstack_compute_secgroup_v2.terraform.name}",
    ]
<% end %>

  provisioner "file" {
    source      = "<%= salt_dir %>/bootstrap/salt"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "<%= salt_dir %>/bootstrap/grains/<%= grains_name %>"
    destination = "/tmp/salt/grains"
  }

  provisioner "file" {
      source      = "<%= ssh_dir %>"
      destination = "/root/.ssh"
  }

  provisioner "remote-exec" {
    inline = [
      <% if exists?("salt_master") %>
      "echo \"master: <%= salt_master %> \" > /tmp/salt/minion.d/minion.conf",
      <% end %>
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
