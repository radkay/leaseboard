# Apply the privileges script after every way a database gets built, so a freshly
# migrated, schema-loaded, prepared or test-prepared database always has exactly the
# reader grants and the function lockdown (CONTRACT.md).
#
# We append the work to Rails' own db tasks with Rake::Task#enhance — the same
# mechanism the Active Record railtie uses to run db:schema:dump after db:migrate
# (activerecord/lib/active_record/railties/databases.rake). enhance docs:
# https://ruby.github.io/rake/Rake/Task.html#method-i-enhance

namespace :db do
  desc "Grant the environment's reader role exactly the contract read surface (idempotent)."
  task privileges: :environment do
    PrivilegesScript.apply!
    Rails.logger&.info("db:privileges: applied the reader grants and function lockdown")
  end
end

# Run the grants right after the schema exists, however it was built. Each hook is a
# real rake task, so invoking db:migrate / db:schema:load / db:prepare / db:test:prepare
# applies them; Rake memoises invoke, so a task that triggers several of these still
# grants exactly once per run.
%w[db:migrate db:schema:load db:prepare db:test:prepare].each do |name|
  next unless Rake::Task.task_defined?(name)

  Rake::Task[name].enhance do
    Rake::Task["db:privileges"].invoke
  end
end
