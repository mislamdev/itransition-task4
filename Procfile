# The command that starts the web server.
#
# NOTE: Render (and Heroku) read this file. The port and the interface come
# from the environment of the platform (PORT), the configuration of Puma is in
# config/puma.rb.
#
# IMPORTANT: the migrations run BEFORE the server starts. Render offers a
# "pre-deploy command" only in the paid plans, therefore they are part of the
# start command. `db:prepare` creates the database and loads the schema at the
# first deployment (and it fills the demo data), afterwards it only runs the
# migrations.
web: bin/rails db:prepare && bundle exec puma -C config/puma.rb
