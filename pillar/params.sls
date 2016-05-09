# the CIDR for cluster IPs (internal IPs for Pods)
cluster_cidr:     '172.20.0.0/16'

# the CIDR for services (virtual IPs for services)
services_cidr:    '172.21.0.0/16'

# port for listening for SSL connections
ssl_port:         '6443'

# certificates
# some of these values MUST match the values ussed when generating the kube-ca.*
ca_name:          'kube-ca'
ca_org:           'SUSE'
admin_email:      'admin@kubernetes'
