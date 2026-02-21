# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip

    if @query.present?
      @results = SearchService.new(query: @query, user: current_user).call
    else
      @results = []
    end
  end
end
