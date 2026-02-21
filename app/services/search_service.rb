# frozen_string_literal: true

class SearchService
  attr_reader :query, :user

  def initialize(query:, user:)
    @query = query.to_s.strip
    @user = user
  end

  def call
    return Upload.none if query.blank?

    uploads = base_scope

    # Parse the query for date components and text
    parsed = QueryParser.parse(query)

    # Apply text search on title and caption
    if parsed[:text].present?
      text_query = "%#{sanitize_like(parsed[:text])}%"
      uploads = uploads.where("uploads.title ILIKE :q OR uploads.caption ILIKE :q", q: text_query)
    end

    # Apply date filters
    if parsed[:date_range]
      uploads = uploads.where(date_taken: parsed[:date_range])
    end

    uploads.order(date_taken: :desc, created_at: :desc).limit(100)
  end

  private

  def base_scope
    Upload.joins(:gallery)
          .where(galleries: { user_id: user.id })
          .includes(:gallery, file_attachment: :blob)
  end

  def sanitize_like(string)
    string.gsub(/[%_]/) { |char| "\\#{char}" }
  end
end
