# frozen_string_literal: true

class TimelineController < ApplicationController
  before_action :authenticate_user!

  SAMPLE_LIMIT = 10

  def index
    @decades = decades_with_samples
  end

  def decade
    @decade_start = parse_decade(params[:decade])
    @years = years_with_samples(@decade_start)
  end

  def year
    @decade_start = parse_decade(params[:decade])
    @year = params[:year].to_i
    @months = months_with_samples(@year)
  end

  def month
    @decade_start = parse_decade(params[:decade])
    @year = params[:year].to_i
    @month = params[:month].to_i
    @uploads = month_uploads(@year, @month)
  end

  private

  def base_scope
    scope = Upload.where.not(date_taken: nil)
    scope = scope.where(user_id: current_user.id) unless current_user.admin?
    scope
  end

  def parse_decade(decade_param)
    decade_param.to_s.gsub(/s$/, "").to_i
  end

  def decades_with_samples
    # Query to get decade groupings with counts and sample IDs
    # Note: GROUP BY must use position (1) since PostgreSQL doesn't allow alias in GROUP BY
    results = base_scope
      .select(
        "FLOOR(EXTRACT(YEAR FROM date_taken) / 10) * 10 AS decade_start",
        "COUNT(*) AS photo_count",
        "(ARRAY_AGG(uploads.id ORDER BY date_taken DESC))[1:#{SAMPLE_LIMIT}] AS upload_ids"
      )
      .group(Arel.sql("1"))
      .order(Arel.sql("1 DESC"))

    build_grouped_data(results, :decade_start)
  end

  def years_with_samples(decade_start)
    decade_end = decade_start + 9
    results = base_scope
      .where("EXTRACT(YEAR FROM date_taken) BETWEEN ? AND ?", decade_start, decade_end)
      .select(
        "EXTRACT(YEAR FROM date_taken)::integer AS year_value",
        "COUNT(*) AS photo_count",
        "(ARRAY_AGG(uploads.id ORDER BY date_taken DESC))[1:#{SAMPLE_LIMIT}] AS upload_ids"
      )
      .group(Arel.sql("1"))
      .order(Arel.sql("1 DESC"))

    build_grouped_data(results, :year_value)
  end

  def months_with_samples(year)
    results = base_scope
      .where("EXTRACT(YEAR FROM date_taken) = ?", year)
      .select(
        "EXTRACT(MONTH FROM date_taken)::integer AS month_value",
        "COUNT(*) AS photo_count",
        "(ARRAY_AGG(uploads.id ORDER BY date_taken DESC))[1:#{SAMPLE_LIMIT}] AS upload_ids"
      )
      .group(Arel.sql("1"))
      .order(Arel.sql("1 DESC"))

    build_grouped_data(results, :month_value)
  end

  def month_uploads(year, month)
    base_scope
      .where("EXTRACT(YEAR FROM date_taken) = ? AND EXTRACT(MONTH FROM date_taken) = ?", year, month)
      .includes(file_attachment: :blob)
      .order(date_taken: :desc)
  end

  def build_grouped_data(results, key_field)
    return [] if results.empty?

    # Collect all sample IDs for batch loading
    all_sample_ids = results.flat_map { |r| parse_pg_array(r.upload_ids) }

    # Batch load all samples with eager-loaded attachments
    samples_by_id = Upload
      .where(id: all_sample_ids)
      .includes(file_attachment: :blob)
      .index_by(&:id)

    results.map do |result|
      sample_ids = parse_pg_array(result.upload_ids)
      samples = sample_ids.map { |id| samples_by_id[id] }.compact

      {
        key: result.send(key_field).to_i,
        count: result.photo_count,
        samples: samples,
        overflow: [ result.photo_count - samples.size, 0 ].max
      }
    end
  end

  def parse_pg_array(pg_array)
    return [] if pg_array.blank?

    # Handle both string representation and actual array
    if pg_array.is_a?(String)
      pg_array.gsub(/[{}]/, "").split(",").map(&:to_i)
    else
      pg_array.map(&:to_i)
    end
  end
end
