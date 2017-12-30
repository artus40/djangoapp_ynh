#!/bin/bash

# Setup a virtual environnement
venv_setup() {
	path="${final_path}/env"
	sudo virtualenv -p python3 $path
}

venv_activate() {
	local path="${1}/env"
	source "${path}/bin/activate"
}


# Setup a django project
# Arguments are:
#     - path
django_setup_project() {

	# Retrieve arguments
	base_path=$1

	# Activate virtual env
	venv_activate $base_path

	# Create django project
	project_name="app"
	django_path="${base_path}/${project_name}"
	django-admin startproject $project_name $django_path

	# Run database initialization
	python "${django_path}/manage.py" migrate

	# Create admin and set a password
        # TODO: set up a useful admin user (like an existing one in Yunohost)	
	# WARNING: this uses user, domain and password global variables !
	python "${django_path}/manage.py" createsuperuser --no-input --username=$user --email="${user}@${domain}"
	python "${django_path}/manage.py" shell -c "
from django.contrib.auth.models import User; 
admin = User.objects.get(username='${user}'); 
admin.set_password('${password}'); 
admin.save()"
}

# Set up custom settings
django_setup_settings() {

	#TODO: update settings in auto-generated app/settings.py file
	# Setup allowed_hosts, secret_key and script_name

	#TODO: check if a custom 'settings.py' file is in conf, if so, copy it to app/app_settings.py
	# and use it in gunicorn service
}
