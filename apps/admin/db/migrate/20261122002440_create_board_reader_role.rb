class CreateBoardReaderRole < ActiveRecord::Migration[8.1]
  # The password is never a literal: it comes from the environment (BOARD_READER_PASSWORD),
  # set from .env.example locally and from Render env vars in production. Roles are not
  # dumped to structure.sql, so the fitness test provisions its own copy for CI.
  def up
    BoardReaderRole.install!(connection, password: ENV.fetch("BOARD_READER_PASSWORD"))
  end

  def down
    BoardReaderRole.revoke!(connection)
  end
end
