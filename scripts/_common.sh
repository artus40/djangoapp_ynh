#!/bin/bash

# Setup a virtual environnement
venv_setup() {
	venv_path="${final_path}/env"
	sudo virtualenv -p python3 $path
}

venv_pip() {
	venv_activate 
	pip "$@"
	venv_deactivate
}

# $venv_path must be set ! 
# It usually is by running venv_setup
venv_activate() {
	source "${venv_path}/bin/activate"
}

venv_deactivate() {
	deactivate
}

# Setup a django project named 'app' at given path.
# It reaches `$user`, `$domain` and `$password` variables (must be set) 
# to define the admin user credentials.
django_setup_project() {

	# Retrieve arguments
	base_path=$1
	project_name="app"

	# Create base folder for django
	django_path="${base_path}/${project_name}"
	mkdir -p $django_path
	
	# Activate virtual env
	venv_activate

	# Create django project
	django-admin startproject $project_name $django_path

	# Run database initialization
	python "${django_path}/manage.py" migrate

	# Create admin and set a password
        # TODO: set up a useful admin user (like an existing one in Yunohost)	
	# mail=$(ynh_get_user_info $admin mail)

	# WARNING: this uses user, domain and password global variables !
	mail="${user}@${domain}"
	python "${django_path}/manage.py" shell -c "\
from django.contrib.auth.models import User; \
admin = User.objects.create_superuser('${user}', \
                           email='${mail}', \
			   password='${password}'); \
admin.save()"

	# Before exit
	venv_deactivate
}

# Set up custom settings
#django_setup_settings() {

	#TODO: update settings in auto-generated app/settings.py file
	# Setup allowed_hosts, secret_key and script_name

	#TODO: check if a custom 'settings.py' file is in conf, if so, copy it to app/app_settings.py
	# and use it in gunicorn service
#}
