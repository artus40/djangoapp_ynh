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

# Run pip in venv
venv_pip() {
	local path="${1}/env"
	# ...
}

venv_python() {
	local path="${1}/env"
}

# Setup a django project
# Arguments are:
#     - path
setup_django_project() {
	
	base_path=$1

	venv_activate $base_path
	# Create django project
	project_name="app"
	django_path="${base_path}/${project_name}"
	app_path="${django_path}/${project_name}"
	django-admin startproject $project_name $django_path

	# Setup

	python "${django_path}/manage.py" migrate
	# Create admin 
	python "${django_path}/manage.py" createsuperuser 
	#TODO: Find some generic and easy procedure
	# Customize settings.py

	# Fill out conf/settings.py variables
	# TODO: allowed_hosts, secret_key, script_name



	# Generate secret_key
	echo "generated_secret_key" > "${app_path}/secret.txt"



	# To customize settings, you shall create a 'settings.py' file
	# inside source folder.
	# It shall import django-generated settings with :
	# ```from .base_settings import *```
	if [ -e "../sources/app_settings.py" ]
	then
	    sudo cp ../conf/settings.py "${app_path}/base_settings.py"
	else
	    sudo cp ../conf/settings.py "${app_path}/settings.py"
	fi



}
