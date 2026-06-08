[options]
admin_passwd = admin
db_host = {{POSTGRES_HOST}}
db_port = {{POSTGRES_PORT}}
db_user = odoo
db_password = odoo
db_name = socialregistrydb
server_wide_modules = web,queue_job
addons_path = {{ODOO_PATH}}/addons,{{OPENG2P_WORKSPACE}}/openg2p-social-registry-community-addons,{{OPENG2P_WORKSPACE}}/openg2p-social-registry,{{OPENG2P_WORKSPACE}}/openg2p-registry,{{OPENG2P_WORKSPACE}}/openg2p-odoo-commons
default_productivity_apps = True
http_port = {{SR_HTTP_PORT}}
gevent_port = 8073
longpolling_port = 8074
log_level = info

[queue_job]
channels = root:4
