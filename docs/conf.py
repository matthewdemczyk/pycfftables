import os
import sys
import ctypes

# Force load libcfftables so the dynamic linker can find it
venv_path = os.environ.get('READTHEDOCS_VIRTUALENV_PATH', '')
if venv_path:
    ctypes.CDLL('libflint.so', mode=ctypes.RTLD_GLOBAL)
    ctypes.CDLL(os.path.join(venv_path, 'lib', 'libcfftables.so.0'), mode=ctypes.RTLD_GLOBAL)

autodoc_typehints = 'both'
autodoc_typehints_description_target = 'documented'

# Extensions
extensions = [
    'sphinx.ext.autodoc',      # Auto-generate docs from docstrings
    'sphinx.ext.napoleon',     # Support Google/NumPy style docstrings
    'sphinx.ext.viewcode',     # Add links to source code
    'sphinx.ext.intersphinx',  # Link to other projects' docs
]

# Intersphinx - link to Python docs
intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
}

# -- Project information ------------------------------
project = 'pycfftables'
copyright = '2026, Matthew Demczyk'
author = 'Matthew Demczyk'
release = '0.1.0'

# -- General configuration ----------------------------
templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']



# -- Options for HTML output --------------------------
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
html_theme_options = {
    'collapse_navigation': False,  # keeps all sections expanded
    'navigation_depth': 4,         # how many levels deep to show
    'includehidden': True,
}
