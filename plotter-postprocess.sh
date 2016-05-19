#!/bin/sh

# post-processing scripts get the slic3r gcode file as parameter
# (to be edited in-place) and the slic3r settings in the environment.

#sed -n 's/;.*//; s/E[^ ]* \?//; /^M106/d; /^M107/d; /^$/!p;' all.gcode > tux.gcode

# apparently the slic3r environment doesn't work (no variables set):
# echo "slic3r env:" >&2
# env | grep ^SLIC3R >&2
# echo "ok." >&2
# STDOUT is also working.

# However, the slic3r config is available as comments at the end of the gcode file.


# remove comments, remove extrusion, remove fan on/off commands, remove empty lines. Now the file is ready to be written directly to the printer.
sed -n -i -e 's/;.*//; /^G92 E0$/d; s/E[^ ]* \?//; /^M106/d; /^M107/d; /^$/!p;' "$1"
