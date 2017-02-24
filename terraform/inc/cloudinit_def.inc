<% if provider == "libvirt" %>

    resource "libvirt_cloudinit" "<%= name %>_ci" {
        <% if exists?("count") %>
            count              = <%= count %>
            name               = "<%= cluster_prefix %>_<%= name %>${count.index}_ci.iso"
            local_hostname     = "<%= fqdn("#{name}${count.index}") %>"
        <% else %>
            name               = "<%= cluster_prefix %>_<%= name %>_ci.iso"
            local_hostname     = "<%= fqdn(name) %>"
        <% end %>

        ssh_authorized_key = "${file("<%= ssh_key %>.pub")}"
        pool               = "<%= volume_pool %>"

        <% if enabled? "is_dashboard" %>
            user_data  = "${data.template_file.dashboard.rendered}"
        <% else %>
            user_data  = "${data.template_file.minion.rendered}"
        <% end %>
    }

<% end %>
