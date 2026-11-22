# Rebuild the test database's schema in place. Rails' usual refresh (db:test:prepare)
# purges the database — drop + create — which needs privileges the non-superuser owner
# (admin_test) doesn't have. Instead, drop everything the owner owns and reload
# structure.sql; db:schema:load is enhanced to re-apply db/privileges.sql.
#
# Use it after a schema change, as the test owner:
#   RAILS_ENV=test bin/rails db:test:refresh
namespace :db do
  namespace :test do
    desc "Rebuild the test database's schema in place (non-superuser owner can't purge the database)."
    task refresh: :environment do
      unless Rails.env.test?
        abort "db:test:refresh only runs in the test environment (use RAILS_ENV=test)."
      end

      # DROP OWNED BY is always permitted on one's own objects, so this works without
      # superuser and without dropping the database itself.
      ActiveRecord::Base.connection.execute("DROP OWNED BY CURRENT_USER CASCADE")
      Rake::Task["db:schema:load"].invoke
      puts "db:test:refresh: #{ActiveRecord::Base.connection.current_database} schema rebuilt."
    end
  end
end
