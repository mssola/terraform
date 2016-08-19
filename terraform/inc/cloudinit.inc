<% if provider == "libvirt" %>
  <% if exists?("count") %>
    cloudinit = "${element(libvirt_cloudinit.<%= name %>_ci.*.id, count.index)}"
  <% else %>
    cloudinit = "${libvirt_cloudinit.<%= name %>_ci.id}"
  <% end %>
<% end %>
