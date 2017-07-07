
<% if exists? "floating_ip" %>

    <% if provider == "openstack" %>

        resource "openstack_compute_floatingip_v2" "fip_<%= name %>" {
            <% if exists? "count" %>
                count = <%= count %>
            <% end %>
            pool = "floating"
        }

        output "fip_<%= name %>" {
            <% if exists? "count" %>
                value = "${join(",",openstack_compute_floatingip_v2.fip_<%= name %>.*.address)}"
            <% else %>
                value = "${openstack_compute_floatingip_v2.fip_<%= name %>.address}"
            <% end %>
        }

    <% elsif provider == "libvirt" %>

        output "ip_<%= name %>" {
            <% if exists? "count" %>
                value = "${join(",", libvirt_domain.<%= name %>.*.network_interface.0.addresses.0)}"
            <% else %>
                value = "${libvirt_domain.<%= name %>.network_interface.0.addresses.0}"
            <% end %>
        }

    <% end %>

<% end %>

resource "<%= domain_type %>" "<%= name %>" {

    <% if !exists? "hostname" %>
        <% set("hostname", name) %>
    <% end %>

    <% if exists? "count" %>
        <% full_name     = "#{cluster_prefix}_#{name}${count.index}" %>
        <% full_hostname = fqdn("#{hostname}${count.index}") %>

        count            = <%= count %>
        name             = "<%= full_name %>"
        metadata         = "<%= full_hostname %>,${count.index}"
    <% else %>
        <% full_name     = "#{cluster_prefix}_#{name}" %>
        <% full_hostname = fqdn(hostname) %>

        name             = "<%= full_name %>"
        metadata         = "<%= full_hostname %>"
    <% end %>

    <% if exists? "depends_on" %>
        depends_on = <%= depends_on %>
    <% end %>

    <%= render "disk.inc", volume_id: name %>
    <%= render "net_iface.inc",
        hostname: full_hostname,
        count: count,
        floating_ip: floating_ip,
        bastion: bastion %>

    <% if provider == "libvirt" %>

        <% if exists? "#{name}_memory" %>
            memory = <%= eval("#{name}_memory") %>
        <% elsif exists?("memory") %>
            memory = <%= memory %>
        <% end %>

        <% if exists? "#{name}_cpus" %>
            vcpu = <%= eval("#{name}_cpus") %>
        <% elsif exists?("cpus") %>
            vcpu = <%= cpus %>
        <% end %>

        <% if enabled?("is_uefi_image") && exists?("firmware") %>
            firmware = "<%= firmware %>"
        <% end %>

        graphics {
          type        = "vnc"
          listen_type = "address"
        }

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

    <%= render "domain_provision.inc" %>
    <%= render "domain_cloudinit.inc", name: name, count: count %>
}
