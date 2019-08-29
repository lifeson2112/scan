#!/usr/bin/env python

import re
import sys
import json

# From analyzing the container names in auk57 I see they have this format (values pulled in from docker label):
#   k8s_{io.kubernetes.container.name}_{io.kubernetes.pod.name}_{io.kubernetes.pod.namespace}_{io.kubernetes.pod.uid}

# example:
# k8s_node-exporter_node-exporter-someid_kube-system_whatever-uuid-string-thingy_number
# k8s_POD_node-exporter-someid_kube-system_whatever-uuid-string-thingy_number

# there are some non-conforming formats though:
# k8s_neutron-metadata-agent-default_neutron-metadata-agent-default-nk5gb_openstack_0af70cbf-c90e-11e9-a3b6-246e96d42fa2_0
# k8s_POD_neutron-metadata-agent-default-nk5gb_openstack_0af70cbf-c90e-11e9-a3b6-246e96d42fa2_0


namespace_scan = ['openstack', 'osh-infra', 'ucp']

def cname_to_k8sname(content):
    filter_results = {'rejected': [],
                      'accepted': [],
                      'not_applicable': []}

    for line in content:
        line = line.replace("\n","")
        name_parts = line.split("_")
        container_type = 'container'
        fullname = name_parts[2]
        namespace = name_parts[3]

        if not any(namespace in ns for ns in namespace_scan):
            filter_results['not_applicable'].append(fullname)
            continue 

        if name_parts[1] == "POD":
            container_type = "pod"

        # We only need to look at containers with this postfix 
        if not re.match(r".*[a-z0-9]{10}-[a-z-0-9]{5}$", fullname):
            filter_results['rejected'].append(fullname)
        else:
            filter_results['accepted'].append(fullname)

    return filter_results

def main():
    filename = "cname_format.txt"
    results = {}
    with open(filename, "r") as content:
        results = cname_to_k8sname(content) 

    print json.dumps(results, indent=4, sort_keys=True)
  

if __name__ == "__main__":
    main()

