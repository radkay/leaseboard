class Resident < ApplicationRecord
  has_many :leases, dependent: :destroy

  validates :first_name, :last_name, :email, :phone, presence: true
  validates :email, uniqueness: { case_sensitive: false }

  def full_name
    "#{first_name} #{last_name}"
  end
end
