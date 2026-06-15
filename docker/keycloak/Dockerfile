FROM quay.io/keycloak/keycloak:26.0.7
COPY keycloak/realm-export.json /opt/keycloak/data/import/realm-export.json
# Copy certificates into the Keycloak configuration directory
# Note: These are either copied from local 'certs' or empty if not present during build.
# The prelaunch-script.phala.sh will generate them on the CVM.
COPY certs /opt/keycloak/conf/
