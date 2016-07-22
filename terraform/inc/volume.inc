<% if provider == "libvirt" %>
resource "libvirt_volume" "<%= name %>_volume" {
    <% if exists?("count") %>
    count            = <%= count %>
    name             = "<%= cluster_prefix %>_<%= name %>${count.index}.img"
    <% else %>
    name             = "<%= cluster_prefix %>_<%= name %>.img"
    <% end %>

    pool             = "<%= volume_pool %>"

    <% if exists?("volume_base") %>
    base_volume_name = "<%= volume_base %>"
    <% elsif exists?("volume_source") %>
    source          = "<%= volume_source %>"
    <% end %>

}
<% end %>
