# djangoapp_ynh
template django application for yunohost

!! This is a work-in-progress, and shall not be used as-is in production. !!

# Description

This is a template to package your own django application as a Yunohost app.
It is configured to setup a new django project, create an admin, install your embedded modules and create production settings.
Gunicorn is used to serve the application using a socket file. 

# Usage

  * Clone this repo and put your django related files inside django/
    * If you have custom project settings, put them inside django/settings.py.
    * Put your project url configuration under django/urls.py
    * Put any embedded modules inside django/ as well
  * Tweak the install script with your specific steps

