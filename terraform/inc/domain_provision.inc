<% ################## %>
<% # Some ERB macros  %>
<% ################## %>

<% copy = lambda do |src, dst| %>
    provisioner "file" {
        source      = "<%= src %>"
        destination = "<%= dst %>"
    }
<% end %>

<% run = lambda do |exe, args=''| %>
    provisioner "remote-exec" {
        inline = [
            "<%= exe %> <%= args %>",
        ]
    }
<% end %>

<% run_sh = lambda do |exe, args=''| %>
    <% run ["bash #{exe}", args] %>
<% end %>

<% overwrite = lambda do |src, dst| %>
    # overwrite <%= dst %> with the contents of <%= src %>
    <% run ["rm -rf #{dst}"] %>
    <% copy[src, dst] %>
<% end %>

<% ################## %>

<% run  ["mkdir -p /root/.ssh"] %>
<% copy ["#{ssh_key}", "/root/.ssh/id_rsa"] %>
<% copy ["#{ssh_key}.pub", "/root/.ssh/id_rsa.pub"] %>
<% copy ["#{tf_dir}/provision", "/tmp/"] %>

<% if enabled? "is_dashboard" %>

    <% if enabled? "rw" or exists? "salt_dir" or exists? "manifests_dir" %>
        <% run_sh ["/tmp/provision/enable-rw.sh", "start"] %>
        <% if exists? "salt_dir" %>
            <% overwrite [salt_dir, "/usr/share/salt/kubernetes"] %>
        <% end %>
        <% if exists? "manifests_dir" %>
            <% overwrite [manifests_dir, "/usr/share/caasp-container-manifests"] %>
        <% end %>
        <% if !enabled? "rw" %>
            <% run_sh ["/tmp/provision/enable-rw.sh", "stop"] %>
        <% end %>
    <% end %>

    <% prov_dir = "admin" %>
    <% prov_args  = "--dashboard #{dashboard}" %>
    <% if exists? "infra" %>
        <% prov_args  = "#{prov_args} --infra #{infra}" %>
    <% end %>
    <% if enabled? "e2e" %>
        <% prov_args  = "#{prov_args} --e2e" %>
    <% end %>
    <% if exists? "docker_reg" %>
        <% prov_args  = "#{prov_args} --docker-reg #{docker_reg}" %>
    <% end %>
    <% if exists? "pillar" %>
        <% prov_args  = "#{prov_args} --pillar #{pillar}" %>
    <% end %>

<% else %>

    <% if enabled? "rw" %>
        <% run_sh ["/tmp/provision/enable-rw.sh", "start"] %>
    <% end %>

    <% prov_dir = "workers" %>
    <% prov_args  = "--dashboard #{dashboard}" %>
    <% if !enabled?("skip_role_assignments") && !enabled?("skip_dashboard") %>
      <% prov_args  = "#{prov_args} --role #{role}" %>
    <% end %>

<% end %>

<% run_sh ["/tmp/provision/#{prov_dir}/provision.sh", prov_args] %>
