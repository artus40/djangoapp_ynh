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

# Install a module located in django/ base folder.
# Takes the module name as only argument.
django_install_from_folder() {
	local module_name=$1
	# Copy files
	cp -r ../django/${module_name} ${django_path}/
	# Update database
	venv_activate
	python $django_path/manage.py makemigrations $module_name
	python $django_path/manage.py migrate
	venv_deactivate
}

# Set up custom settings
django_setup_settings_and_urls() {

	# Settings
	secret_key="generated_secret_key" #TODO!
	domain="192.168.0.1"

	# Import settings.py from 'conf' folder, if any.
	settings_pypath="app.settings"
	[[ -e ../conf/settings.py ]] && \
		cp ../conf/settings.py "${django_path}/app_settings.py"
		settings_pypath=".app_settings"

	
	# Create a 'prod_settings.py' conf file to use with gunicorn service
	echo "\
from ${settings_pypath} import *

ALLOWED_HOSTS = ['${domain}',]
SECRET_KEY = '${secret_key}'

DEBUG = False
	" > $django_path/prod_settings.py

	# Override defaults urls conf from project folder
	[[ -e ../conf/urls.py ]] && \
		cp ../conf/urls.py "${django_path}/${project_name}/urls.py"
}

