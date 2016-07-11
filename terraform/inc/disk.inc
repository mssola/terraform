<% if provider == "libvirt" %>

    disk {
      <% if exists?("count") %>
        volume_id   = "${element(libvirt_volume.<%= volume_id %>_volume.*.id, count.index)}"
      <% else %>
        volume_id   = "${libvirt_volume.<%= volume_id %>_volume.id}"
      <% end %>
    }

<% elsif provider == "openstack" %>

    image_name  = "<%= openstack_image %>"

<% end %>
