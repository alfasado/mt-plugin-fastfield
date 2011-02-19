# About Fast Field plugin for Movable Type

## Synopsis

Fast Loading CustomField.

## Settings

You can specify the following directives in mt-config.cgi.

**Initialization is performed when the specified string starts with the application mode.**

    LoadCustomFieldMode rebuild # default
    LoadCustomFieldMode save    # default
    LoadCustomFieldMode preview # default
    LoadCustomFieldMode delete  # default

## Download YAML file and Install

Download YAML file from menu 'CustomField' &raquo; 'Download YAML' and put plugins/FastField/yaml/Fields.yaml.
CustomField initialize using YAML file(and using Memcached).
