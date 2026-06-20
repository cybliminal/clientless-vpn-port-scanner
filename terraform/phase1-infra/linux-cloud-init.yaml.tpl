#cloud-config
package_update: true

debconf_selections: |
  slapd slapd/internal/generated_adminpw password ${ldap_admin_password}
  slapd slapd/internal/adminpw password ${ldap_admin_password}
  slapd slapd/password2 password ${ldap_admin_password}
  slapd slapd/password1 password ${ldap_admin_password}
  slapd slapd/domain string ${ldap_domain}
  slapd shared/organization string ${ldap_domain}
  slapd slapd/purge_database boolean false
  slapd slapd/move_old_database boolean true
  slapd slapd/no_configuration boolean false

packages:
  - nginx
  - postgresql
  - redis-server
  - slapd
  - ldap-utils
  - bind9
  - rpcbind

runcmd:
  - sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
  - echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/*/main/pg_hba.conf
  - systemctl restart postgresql
  - sed -i "s/^bind .*/bind 0.0.0.0/" /etc/redis/redis.conf
  - sed -i "s/^# requirepass.*/requirepass ${redis_password}/" /etc/redis/redis.conf
  - systemctl restart redis-server
  - openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -keyout /etc/ldap/ldap-key.pem -out /etc/ldap/ldap-cert.pem -subj "/CN=${ldap_domain}"
  - chown openldap:openldap /etc/ldap/ldap-key.pem /etc/ldap/ldap-cert.pem
  - sed -i 's#^SLAPD_SERVICES=.*#SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"#' /etc/default/slapd
  - systemctl restart slapd
  - systemctl enable --now nginx
  - systemctl enable --now bind9
  - systemctl enable --now rpcbind
  - systemctl enable --now ssh
