class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles
  enum :role, { member: 0, admin: 1 }, default: :member

  # Validations
  validates :name, presence: true
  validates :role, presence: true

  # Associations
  has_many :galleries, dependent: :destroy
  has_many :uploads, dependent: :destroy
end
