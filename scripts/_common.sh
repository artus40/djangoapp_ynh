#!/bin/bash

# -------------------------------------
#  VIRTUAL ENVIRONMENT
# -------------------------------------

# Setup a virtual environnement
venv_setup() {
	venv_path="$1/env"
	python3 -m venv $venv_path
}

# Use pip inside the virtual environnement
venv_pip() {
	venv_activate 
	pip "$@"
	venv_deactivate
}

# $venv_path must be set ! 
# It usually is by running venv_setup
venv_activate() {
	set +o nounset # To avoid unset errors
	source "${venv_path}/bin/activate"
}

venv_deactivate() {
	deactivate
	set -o nounset
}


# -------------------------------------
#  DJANGO
# -------------------------------------


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
        # Add the project folder to PYTHONPATH
        export PYTHONPATH=$PYTHONPATH:${django_path} 
	# Run database initialization
	python "${django_path}/manage.py" migrate

	# Create admin and set a password
        # TODO: set up a useful admin user (like an existing one in Yunohost)	
	# mail=$(ynh_get_user_info $admin mail)

	# WARNING: this uses user, domain and password global variables !
	mail="${admin}@${domain}"
	python "${django_path}/manage.py" shell -c "\
from django.contrib.auth.models import User; \
admin = User.objects.create_superuser('${admin}', \
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
	django-admin makemigrations $module_name 
	django-admin migrate
	venv_deactivate
}

# Set up custom settings
django_setup_settings_and_urls() {
	# Settings
        # Generate secret key
	secret_key="generated_secret_key" #TODO: generate a secret key!
	# Import settings.py from 'conf' folder, if any.
	if [ -e ../django/settings.py ] 
        then
	    cp ../django/settings.py "${django_path}/${project_name}/custom_settings.py"
	    settings_filename="custom_settings"
        else
            settings_filename="settings"
        fi
	# Create a 'prod_settings.py' conf file to use with gunicorn service
	echo "\
from ${project_name}.${settings_filename} import *

ALLOWED_HOSTS = ['${domain}',]
# SECRET_KEY = '${secret_key}'

STATIC_URL = '${path_url}/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static/')
FORCE_SCRIPT_NAME = '${path_url}'
DEBUG = True
	" > $django_path/prod_settings.py

        # Set environnement variable for django-admin
        export DJANGO_SETTINGS_MODULE=prod_settings

	# Override defaults urls conf from project folder
        if [ -e ../django/urls.py ]
        then
	    cp ../django/urls.py "${django_path}/${project_name}/urls.py"
        fi
}

