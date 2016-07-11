<% if provider == "libvirt" %>
resource "libvirt_volume" "<%= name %>_volume" {
    <% if exists?("count") %>
    count            = <%= count %>
    name             = "<%= name %>${count.index}.img"
    <% else %>
    name             = "<%= name %>.img"
    <% end %>

    pool             = "<%= storage_pool %>"
    base_volume_name = "<%= base_volume %>"
}
<% end %>
