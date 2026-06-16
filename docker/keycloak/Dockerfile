FROM quay.io/keycloak/keycloak:26.0.7
COPY keycloak/realm-export.json /opt/keycloak/data/import/realm-export.json
# Note: These are either copied from local 'certs' or empty if not present during build.
# The prelaunch-script.phala.sh will generate them on the CVM.
# Realm export is also volume-mounted in docker-compose for development flexibility.
COPY certs /opt/keycloak/conf/
