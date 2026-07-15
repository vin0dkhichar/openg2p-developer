[options]
admin_passwd = admin
db_host = {{POSTGRES_HOST}}
db_port = {{POSTGRES_PORT}}
db_user = pbmsuser
db_password = pbmspass
db_name = pbmsdb
server_wide_modules = web,queue_job
addons_path = {{ODOO_PATH}}/addons,{{PBMS_PATH}}/odoo/community-addons,{{PBMS_PATH}}/odoo,{{PBMS_PATH}}/odoo/extensions,{{OPENG2P_WORKSPACE}}/openg2p-odoo-commons
default_productivity_apps = True
http_port = {{PBMS_HTTP_PORT}}
gevent_port = 8072
log_level = info

[queue_job]
channels = root:4
