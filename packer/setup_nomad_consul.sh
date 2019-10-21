#!/bin/sh
set -e

# Environment variables are set by packer
/tmp/bundle/install-nomad/install-nomad --version "${NOMAD_VERSION}"

/tmp/bundle/install-consul/install-consul --version "${CONSUL_VERSION}"
