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
    <%= render "net_iface.inc",
        hostname: full_hostname,
        floating_ip: floating_ip,
        bastion: bastion %>

    <% if provider == "libvirt" %>

        <% if exists?("#{name}_memory")%>
            memory = <%= eval("#{name}_memory") %>
        <% elsif exists?("memory") %>
            memory = <%= memory %>
        <% end %>

        <% if is_uefi_image.to_bool && exists?("firmware") %>
            firmware = "<%= firmware %>"
        <% end %>

    <% elsif provider == "openstack" %>

        <% if exists? "#{name}_flavor" %>
            flavor_name = <%= eval("#{name}_flavor") %>
        <% elsif exists? "flavor_name" %>
            flavor_name  = "<%= flavor_name %>"
        <% else %>
            flavor_name  = "m1.small"
        <% end %>

        key_pair         = "<%= cluster_prefix %>_keypair"

        security_groups = [
            "default",
            "${openstack_compute_secgroup_v2.terraform.name}",
        ]
    <% end %>

    provisioner "remote-exec" {
        inline = [
            "[ -d /root/.ssh ] || mkdir -p /root/.ssh",
        ]
    }

    provisioner "file" {
        source      = "<%= ssh_key %>"
        destination = "/root/.ssh/id_rsa"
    }

    provisioner "file" {
        source      = "<%= ssh_key %>.pub"
        destination = "/root/.ssh/id_rsa.pub"
    }

    provisioner "file" {
        source      = "<%= salt_dir %>/bootstrap/salt"
        destination = "/tmp"
    }

    <%# provision depends whether this is the Salt master or not %>
    <%# we make that distinction with the "salt_master" argument: %>
    <%# a node with no "salt_master" is the salt master %>

    <% if !exists? "salt_master" %>

        <%# *** salt master *** %>

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
                <% prov_args      = "-D --infra #{infra} -h #{full_hostname}" %>
                <% if exists? "e2e" %>
                    <% prov_args  = "#{prov_args} --e2e" %>
                <% end %>
                "bash /tmp/salt/provision-salt-master.sh <%= prov_args %>",
            ]
        }

    <% else %>

        <%# *** NOT salt master *** %>

        provisioner "file" {
            source      = "<%= salt_dir %>/bootstrap/grains/<%= hostname %>"
            destination = "/tmp/salt/grains"
        }

        provisioner "remote-exec" {
            inline = [
                <% prov_args      = "-h #{full_hostname}" %>
                <% if exists? "salt_master" %>
                    <% prov_args  = "#{prov_args} --salt-master #{salt_master}" %>
                <% end %>

                "bash /tmp/salt/provision-salt-minion.sh <%= prov_args %>",
            ]
        }
    <% end %>

    <%= render "cloudinit.inc", name: name, count: count %>
}
