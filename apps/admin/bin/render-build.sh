#!/usr/bin/env bash
# Render Build command for the admin. Render's custom build command replaces its default
# `bundle install`, so this runs it explicitly, then precompiles assets. Keep in sync with
# DEPLOY.md. Migrations run in the separate Release command, not here.
set -o errexit

bundle install

# Assets compile without a real secret; the dummy lets the production env boot for the task.
SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
bin/rails assets:clean
