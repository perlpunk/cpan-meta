## Perl CPAN modules - Meta information

Various vendors are keeping additional information such as missing
dependencies or non-perl dependencies somewhere in their build
system, besides each perl module.

This repo so far is an extraction of the info we have at
https://build.opensuse.org/project/show/devel:languages:perl

### cpanspec.yaml

A collection of all cpanspec.yaml data for each module


### deps.yaml

Extracted BuildRequires / Requires / Recommends / Suggests from
cpanspec.yaml

### patches.yaml

Extracted patches from cpanspec.yaml

### gendeps.yaml

Extracted Requires / BuildRequires from the generated spec files.
This is information from the module's (MY)META.* files plus the additional
dependencies which were added from cpanspec.yaml
