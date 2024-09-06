import math
import os

def define_env(env):
    # Pass this directory as a variable to be used in mkdocs.yml
    env.variables['root_folder'] = os.getcwd() + '\\docs\\'