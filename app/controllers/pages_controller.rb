class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  layout "landing"

  def about
  end

  def colophon
  end
end
