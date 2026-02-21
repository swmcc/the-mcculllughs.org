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
  has_many :external_connections, dependent: :destroy
  has_many :imports, dependent: :destroy

  # External connections helpers
  def connected_to?(provider)
    external_connections.for_provider(provider).exists?
  end

  def connection_for(provider)
    external_connections.for_provider(provider).first
  end
end
