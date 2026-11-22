# db:seed is destructive — it deletes every property, unit, resident and lease before
# reseeding. That is fine for a fresh demo but must never run accidentally against a
# production database. This guard refuses to seed in production unless ALLOW_SEED_RESET=1
# is set explicitly; the intended workflow is to seed exactly once, right after the first
# deploy, then never again.
module SeedReset
  FLAG = "ALLOW_SEED_RESET"

  module_function

  # Pure predicate (env injectable for tests): seeding is allowed anywhere but production,
  # and in production only when the override flag is exactly "1".
  def permitted?(production: Rails.env.production?, override: ENV[FLAG])
    !production || override == "1"
  end

  # Called at the top of db/seeds.rb. Aborts (non-zero exit) when seeding isn't permitted.
  def guard!(**options)
    return if permitted?(**options)

    abort "Refusing to run db:seed in production: it deletes all existing data. " \
          "Seed once after the first deploy by setting #{FLAG}=1."
  end
end
