# README: scalr/scripts

This directory houses TTM-specific scripts for working with Scalr. We may find these become unnecessary
as we create our own 'scalrttm' command-line tool. But we're not there yet.

## Configuring

Create a file `access_info` in this directory. It should contain your Scalr
access credentials, something like this:

    KEY_ID     = 46ab...
    ACCESS_KEY = nxm+4hN...

DO NOT ADD THIS FILE TO git! It's already in `.gitignore` so you shouldn't be able to do so accidentally.