# frozen_string_literal: true

class SearchService
  attr_reader :query, :user

  def initialize(query:, user:)
    @query = query.to_s.strip
    @user = user
  end

  def call
    return Upload.none if query.blank?

    # Parse the query for date components and text
    parsed = QueryParser.parse(query)

    # Try with both text and date filters first
    results = search_with_filters(parsed[:text], parsed[:date_range])

    # If no results and we had both filters, try text-only fallback
    if results.empty? && parsed[:text].present? && parsed[:date_range].present?
      results = search_with_filters(parsed[:text], nil)
    end

    # If still no results, try searching the raw query as text
    if results.empty? && parsed[:text] != query
      raw_query = "%#{sanitize_like(query)}%"
      results = base_scope.where("uploads.title ILIKE :q OR uploads.caption ILIKE :q", q: raw_query)
    end

    results.order(date_taken: :desc, created_at: :desc).limit(100)
  end

  private

  def search_with_filters(text, date_range)
    uploads = base_scope

    if text.present?
      text_query = "%#{sanitize_like(text)}%"
      uploads = uploads.where("uploads.title ILIKE :q OR uploads.caption ILIKE :q", q: text_query)
    end

    if date_range
      uploads = uploads.where(date_taken: date_range)
    end

    uploads
  end

  def base_scope
    Upload.joins(:gallery)
          .where(galleries: { user_id: user.id })
          .includes(:gallery, file_attachment: :blob)
  end

  def sanitize_like(string)
    string.gsub(/[%_]/) { |char| "\\#{char}" }
  end
end
