<% if provider == "libvirt" %>

    <% if cloudinit %>
        <% if exists?("count") %>
            cloudinit = "${element(libvirt_cloudinit.<%= name %>_ci.*.id, count.index)}"
        <% else %>
            cloudinit = "${libvirt_cloudinit.<%= name %>_ci.id}"
        <% end %>

        provisioner "file" {
           <% if exists?("count") %>
             <% hostname = "#{name}${count.index}" %>
           <% else %>
             <% hostname = name %>
           <% end %>
           content = "fqdn: <%= fqdn_or_hostname(hostname) %>\nhostname: <%= fqdn_or_hostname(hostname) %>\n"
           destination = "/etc/cloud/cloud.cfg.d/99_hostname.cfg"
        }

    <% end %>

<% end %>
