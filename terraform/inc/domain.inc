resource "<%= domain_type %>" "<%= name %>" {

    <% if !exists?("hostname") %>
        <% set("hostname", name) %>
    <% end %>

    <% if exists?("count") %>
        <% full_name     = "#{cluster_prefix}_#{name}${count.index}" %>
        <% full_hostname = "#{hostname}${count.index}" %>

        count            = <%= count %>
        name             = "<%= full_name %>"
    <% else %>
        <% full_name     = "#{cluster_prefix}_#{name}" %>
        <% full_hostname = hostname %>

        name             = "<%= full_name %>"
    <% end %>

    <% if exists?("depends_on") %>
        depends_on = <%= depends_on %>
    <% end %>

    <%= render "disk.inc", volume_id: name %>
    <%= render "net_iface.inc", hostname: full_hostname, bastion: "salt" %>

    <% if provider == "libvirt" %>

        <% if is_uefi_image %>
            firmware = "<%= firmware %>"
        <% end %>

    <% elsif provider == "openstack" %>

        <% if !exists? "flavor_name" %>
            flavor_name  = "m1.small"
        <% else %>
            flavor_name  = "<%= flavor_name %>"
        <% end %>
        key_pair         = "${openstack_compute_keypair_v2.keypair.name}"

        security_groups = [
            "default",
            "${openstack_compute_secgroup_v2.terraform.name}",
        ]
    <% end %>

    provisioner "file" {
        source      = "<%= ssh_key %>"
        destination = "/root/.ssh"
    }

    provisioner "file" {
        source      = "<%= ssh_key %>.pub"
        destination = "/root/.ssh"
    }

    provisioner "file" {
        source      = "<%= salt_dir %>/bootstrap/salt"
        destination = "/tmp"
    }

    <%# provision depends whether this is the Salt master or not %>
    <%# we make that distinction with the "salt_master" argument: %>
    <%# a node with no "salt_master" is the salt master %>

    <% if !exists? "salt_master" %>

        provisioner "file" {
            source      = "<%= salt_dir %>/salt"
            destination = "/srv"
        }

        provisioner "file" {
            source      = "<%= salt_dir %>/pillar"
            destination = "/srv"
        }

        provisioner "remote-exec" {
            inline = [
                "mkdir -p /etc/salt/master.d",
            ]
        }

        provisioner "file" {
            source      = "<%= salt_dir %>/salt-conf/"
            destination = "/etc/salt/master.d"
        }

        provisioner "remote-exec" {
            inline = [
                <% if provider == "libvirt" %>
                    "echo 'infrastructure: \"libvirt\"' >> /srv/salt/pillar/params.sls",
                <% else %>
                    "echo 'infrastructure: \"cloud\"' >> /srv/salt/pillar/params.sls",
                <% end %>

                "bash /tmp/salt/provision-salt-master.sh",
            ]
        }

    <% else %>

        provisioner "file" {
            source      = "<%= salt_dir %>/bootstrap/grains/<%= hostname %>"
            destination = "/tmp/salt/grains"
        }

        provisioner "remote-exec" {
            inline = [
                <% if exists?("salt_master") %>
                    "echo \"master: <%= salt_master %> \" > /tmp/salt/minion.d/minion.conf",
                <% end %>

                "bash /tmp/salt/provision-salt-minion.sh",
            ]
        }
    <% end %>

    <%= render "cloudinit.inc", name: name, count: count %>
}
