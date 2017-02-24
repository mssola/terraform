# dashboard

<% unless enabled? "skip_dashboard" %>

    data "template_file" "dashboard" {
        template = "${file("provision/dashboard/cloud-init.cfg")}"
        vars {
            root = "<%= salt_root %>"
        }
    }

<% end %>

# kube-minion

data "template_file" "minion" {
    template = "${file("provision/minion/cloud-init.cfg")}"
    vars {
        root      = "<%= salt_root %>"
        dashboard = "<%= dashboard_ref %>"
    }
}
