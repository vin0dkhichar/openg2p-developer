[options]
admin_passwd = admin
db_host = {{POSTGRES_HOST}}
db_port = {{POSTGRES_PORT}}
db_user = odoo
db_password = odoo
db_name = pbmsdb
server_wide_modules = web,queue_job
addons_path = {{ODOO_PATH}}/addons,{{OPENG2P_WORKSPACE}}/openg2p-pbms-community-addons,{{OPENG2P_WORKSPACE}}/openg2p-pbms-odoo,{{OPENG2P_WORKSPACE}}/openg2p-pbms-odoo-extensions,{{OPENG2P_WORKSPACE}}/openg2p-registry,{{OPENG2P_WORKSPACE}}/openg2p-odoo-commons
default_productivity_apps = True
http_port = {{PBMS_HTTP_PORT}}
gevent_port = 8071
longpolling_port = 8072
log_level = info

[queue_job]
channels = root:4
