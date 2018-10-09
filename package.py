#!/bin/python3
# -*- coding:utf-8 -*-

"""

    A helper script to ease packaging of a django homemade app inside a
    Yunohost application.

    It shall be run against the folder of your working django project.

"""
import sys
import argparse
import shutil
from pathlib import Path

# ----------------- #
# Arguments parsing #
# ----------------- #

parser = argparse.ArgumentParser(
            description="Package a working django project")
parser.add_argument(
    "path",
    help="Path to the django project to package")
parser.add_argument(
    "-d", "--destination",
    default=Path(__file__).parent,
    type=Path,
    help="Build package into this folder")


# ------------------------ #
# Terminal display helpers #
# ------------------------ #


CLEAR = "\x1b[0m"
RED = "\x1b[1;31m"
GREEN = "\x1b[1;32m"


def scroll_back(n):
    """ Scroll back 'n' lines """
    sys.stdout.write(f"\x1b[{n}F")
    sys.stdout.write("\x1b[J")


class Step:
    """
    A step of the packaging process.

    Override the 'process()' method to implement the step logic.
    Arguments are available in 'self.opts', see Program.run_with_args.
    Some utility methods are provided : ask(), copy_file(), write_file().

    """
    message = None
    opts = None

    def __init__(self, args):
        self.opts = args

    def process(self):
        pass

    def run(self):
        self.lines_printed = 1
        print(f"[***] {self.message}... ")
        result = self.process()
        result_str = f"{GREEN}Ok{CLEAR}" if result else f"{RED}Error{CLEAR}"
        # Erase every printed lines and update message line
        scroll_back(self.lines_printed)
        print(f"[{result_str}] {self.message}...")
        return result

    # Utility methods

    def ask(self, msg):
        """ Ask the user for input """
        self.lines_printed += 1
        return input(f"{msg}> ")

    def copy_file(self, src):
        """ Copy a file to the settings folder """
        shutil.copy(src, self.opts['settings_dir'])

    def write_file(self, name, content):
        """ Write the content to a file in settings folder """
        f = open(self.opts['settings_dir'] / name, "w")
        f.write(content)
        f.close()


class Program:

    def __init__(self, steps):
        self.steps = steps

    def run_with_args(self, args):
        # Validate arguments and setup package destination
        PROJECT_DIR = Path(args.path)  # Path to the django project folder
        if not PROJECT_DIR.is_dir():
            print(f"{RED}Path must be a directory !{CLEAR}")
            return

        PROJECT_NAME = PROJECT_DIR.name  # Name of the django project
        TARGET_DIR = args.destination  # Package build target
        if not TARGET_DIR.exists():  # Export the package to a separate folder
            # Create base dir and copy package files
            TARGET_DIR.mkdir()
            shutil.copy("manifest.json", TARGET_DIR)
            shutil.copytree("scripts/", TARGET_DIR / "scripts")
            shutil.copytree("conf/", TARGET_DIR / "conf")

        SETTINGS_DIR = TARGET_DIR / 'django'  # Settings folder
        if not SETTINGS_DIR.exists():
            SETTINGS_DIR.mkdir()
        # Collect configuration options, using absolute paths
        opts = {
            'project_dir': PROJECT_DIR.resolve(),
            'project_name': PROJECT_NAME,
            'target_dir': TARGET_DIR.resolve(),
            'settings_dir': SETTINGS_DIR.resolve(),
        }
        # Run
        print(f"Packaging '{PROJECT_NAME}' in {opts['target_dir']} :")
        results = []
        for step_cls in self.steps:
            step = step_cls(opts)
            results.append(step.run())
        print(f"{GREEN}Your package is ready !{CLEAR}"
              if all(results)
              else f"{RED}There has been some errors !{CLEAR}")


# ---------- #
# Processing #
# ---------- #


class FindSettings(Step):
    """ Find custom settings, if any. """
    message = "Looking for custom settings"

    def process(self):
        # Try to find a python file which name contains 'settings',
        # ignoring project generated 'settings.py'
        def ignored_files(path):
            if path.name == "settings.py":
                return False
            else:
                return True

        def _ask_user():
            exists = self.ask(
                "I did not find any custom settings. Do you have some ? (y/n)")
            if exists == "n":
                return False
            name = self.ask("Where are they located ?")  # Ask for the filename
            settings = self.opts['project_dir'].glob(f"**/{name}")
            # TODO: Find exactly one file
            return _setup(settings)

        def _setup(source):
            # Update the import from project settings
            content = open(source).readlines()
            import_line = f"from {self.opts['project_name']}.settings import *"
            content = list(filter(
                    lambda l: l != import_line,
                    map(
                        lambda l: l.strip('\n'),
                        content)
                    ))
            content.insert(0, "from app.settings import *")
            # Save to 'django/'
            self.write_file('settings.py', "\n".join(content))
            # Get INSTALLED_APPS
            import subprocess
            import_path = source.relative_to(self.opts['project_dir'])
            import_path = str(import_path.with_suffix("")).replace("/", ".")
            apps = subprocess.check_output(
                ["python3", "-c",
                 f"from {import_path} import INSTALLED_APPS;\
                   print(';'.join(INSTALLED_APPS))"
                 ],
                cwd=self.opts['project_dir'])
            apps = str(apps.rstrip(b'\n')).strip("b'").rstrip("\n'")
            self.opts['installed_apps'] = apps.split(';')
            return True

        settings = list(filter(
            ignored_files,
            self.opts['project_dir'].glob("**/*settings.py")))
        count = len(settings)
        if count == 0:  # Found nothing
            return _ask_user()
        elif count == 1:  # Found what we need
            return _setup(settings[0])
        else:  # Multiple files found
            return False


class FindUrls(Step):
    message = "Looking for 'urls.py'"

    def process(self):
        target = self.opts['project_dir'] / self.opts['project_name'] / 'urls.py'
        if target.exists():
            self.copy_file(target)
            return True
        else:
            return False


class FindRequirements(Step):
    message = "Looking for requirements"

    def process(self):
        req = list(self.opts['project_dir'].glob("requirements.txt"))
        count = len(req)
        if count == 1:  # Simple copy
            req = req[0]
            self.copy_file(req)
            return True
        else:
            want_some = self.ask(
                    "I could not find any requirements.txt. Create one ? (y/n)")
            if want_some == "n":
                return True
            # TODO: create requirements.txt
            extra_modules = filter(
                lambda n: not n.startswith("django"),
                self.opts['installed_apps'])
            extra_deps = filter(
                lambda n: n not in self.opts['embedded_mods'],
                extra_modules)
            required = ["django", ] + [f"django-{dep}" for dep in extra_deps]
            self.write_file("requirements.txt", "\n".join(required))
            return True


class FindModules(Step):
    message = "Finding extra modules"

    def process(self):
        embedded_mods = []
        for child in self.opts['project_dir'].iterdir():
            if child.is_dir():
                apps = child / 'apps.py'
                if apps.exists():
                    embedded_mods.append(child.name)
        print("found " + str(embedded_mods))
        self.lines_printed += 1
        right = self.ask("Am I right ? (y/n)")
        if right == "n":
            return False
        self.opts['embedded_mods'] = embedded_mods
        # TODO: confirm and add setup embedded mods inside scripts/install
        return True


class CreateManifest(Step):
    message = "Updating the manifest"

    def process(self):
        import json
        # Retrieve data
        name = self.ask("Name of your app ?")
        _id = name.lower().replace(" ", "_")
        description = self.ask("Please write a short description.")
        maintainer_name = self.ask("Your name ?")
        maintainer_mail = self.ask("Your mail ?")
        # Update the data
        manifest = json.load(open("manifest.json"))
        manifest['id'] = _id
        manifest['name'] = name
        manifest['description'] = {
            'en': description,
        }
        manifest['maintainer'] = {
            'name': maintainer_name,
            'email': maintainer_mail,
        }
        new_content = json.dumps(manifest, indent=4)
        self.write_file("../manifest.json", new_content)
        return True


# ------- #
# Running #
# ------- #

packager = Program([
    CreateManifest,
    FindUrls,
    FindSettings,
    FindModules,
    FindRequirements,
    ])
packager.run_with_args(parser.parse_args())
