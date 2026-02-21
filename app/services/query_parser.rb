# frozen_string_literal: true

class QueryParser
  MONTHS = {
    "jan" => 1, "january" => 1,
    "feb" => 2, "february" => 2,
    "mar" => 3, "march" => 3,
    "apr" => 4, "april" => 4,
    "may" => 5,
    "jun" => 6, "june" => 6,
    "jul" => 7, "july" => 7,
    "aug" => 8, "august" => 8,
    "sep" => 9, "sept" => 9, "september" => 9,
    "oct" => 10, "october" => 10,
    "nov" => 11, "november" => 11,
    "dec" => 12, "december" => 12
  }.freeze

  class << self
    def parse(query)
      return { text: nil, date_range: nil } if query.blank?

      query = query.strip.downcase
      remaining_text = query.dup

      date_range = nil

      # Try various date patterns
      date_range, remaining_text = try_full_date(remaining_text) if date_range.nil?
      date_range, remaining_text = try_month_year(remaining_text) if date_range.nil?
      date_range, remaining_text = try_year_only(remaining_text) if date_range.nil?
      date_range, remaining_text = try_month_only(remaining_text) if date_range.nil?

      # Clean up remaining text
      text = remaining_text.strip.gsub(/\s+/, " ")
      text = nil if text.empty?

      { text: text, date_range: date_range }
    end

    private

    # Matches: 11-04-1979, 11/04/1979, 11.04.1979, 11th April 1979, April 11 1979, etc.
    def try_full_date(query)
      # DD-MM-YYYY or DD/MM/YYYY or DD.MM.YYYY
      if query =~ /\b(\d{1,2})[-\/.](\d{1,2})[-\/.](\d{2,4})\b/
        day, month, year = $1.to_i, $2.to_i, normalize_year($3)
        if valid_date?(year, month, day)
          date = Date.new(year, month, day)
          remaining = query.gsub(/\b\d{1,2}[-\/.]\d{1,2}[-\/.]\d{2,4}\b/, "")
          return [ date.all_day, remaining ]
        end
      end

      # YYYY-MM-DD (ISO format)
      if query =~ /\b(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})\b/
        year, month, day = $1.to_i, $2.to_i, $3.to_i
        if valid_date?(year, month, day)
          date = Date.new(year, month, day)
          remaining = query.gsub(/\b\d{4}[-\/.]\d{1,2}[-\/.]\d{1,2}\b/, "")
          return [ date.all_day, remaining ]
        end
      end

      # 11th April 1979, 11 April 1979
      month_pattern = MONTHS.keys.join("|")
      if query =~ /\b(\d{1,2})(?:st|nd|rd|th)?\s+(#{month_pattern})\s+(\d{2,4})\b/i
        day, month_name, year = $1.to_i, $2.downcase, normalize_year($3)
        month = MONTHS[month_name]
        if month && valid_date?(year, month, day)
          date = Date.new(year, month, day)
          remaining = query.gsub(/\b\d{1,2}(?:st|nd|rd|th)?\s+(?:#{month_pattern})\s+\d{2,4}\b/i, "")
          return [ date.all_day, remaining ]
        end
      end

      # April 11, 1979 or April 11 1979
      if query =~ /\b(#{month_pattern})\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{2,4})\b/i
        month_name, day, year = $1.downcase, $2.to_i, normalize_year($3)
        month = MONTHS[month_name]
        if month && valid_date?(year, month, day)
          date = Date.new(year, month, day)
          remaining = query.gsub(/\b(?:#{month_pattern})\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{2,4}\b/i, "")
          return [ date.all_day, remaining ]
        end
      end

      [ nil, query ]
    end

    # Matches: August 98, Aug 1998, August 1998
    def try_month_year(query)
      month_pattern = MONTHS.keys.join("|")

      if query =~ /\b(#{month_pattern})\s*'?(\d{2,4})\b/i
        month_name, year = $1.downcase, normalize_year($2)
        month = MONTHS[month_name]
        if month
          start_date = Date.new(year, month, 1)
          end_date = start_date.end_of_month
          remaining = query.gsub(/\b(?:#{month_pattern})\s*'?\d{2,4}\b/i, "")
          return [ start_date.beginning_of_day..end_date.end_of_day, remaining ]
        end
      end

      [ nil, query ]
    end

    # Matches: 1998, 98, '98
    def try_year_only(query)
      # Four digit year
      if query =~ /\b(19\d{2}|20\d{2})\b/
        year = $1.to_i
        start_date = Date.new(year, 1, 1)
        end_date = Date.new(year, 12, 31)
        remaining = query.gsub(/\b(?:19\d{2}|20\d{2})\b/, "")
        return [ start_date.beginning_of_day..end_date.end_of_day, remaining ]
      end

      # Two digit year with apostrophe: '98
      if query =~ /'(\d{2})\b/
        year = normalize_year($1)
        start_date = Date.new(year, 1, 1)
        end_date = Date.new(year, 12, 31)
        remaining = query.gsub(/'\d{2}\b/, "")
        return [ start_date.beginning_of_day..end_date.end_of_day, remaining ]
      end

      [ nil, query ]
    end

    # Matches: just "August" or "aug" (assumes current or most recent)
    def try_month_only(query)
      month_pattern = MONTHS.keys.join("|")

      if query =~ /\b(#{month_pattern})\b/i
        month_name = $1.downcase
        month = MONTHS[month_name]
        if month
          # Use current year, or previous year if the month hasn't happened yet
          year = Date.current.year
          year -= 1 if month > Date.current.month

          start_date = Date.new(year, month, 1)
          end_date = start_date.end_of_month
          remaining = query.gsub(/\b(?:#{month_pattern})\b/i, "")
          return [ start_date.beginning_of_day..end_date.end_of_day, remaining ]
        end
      end

      [ nil, query ]
    end

    def normalize_year(year_str)
      year = year_str.to_i
      return year if year >= 100

      # Two digit year: 00-29 = 2000s, 30-99 = 1900s
      year < 30 ? 2000 + year : 1900 + year
    end

    def valid_date?(year, month, day)
      return false unless (1..12).include?(month)
      return false unless (1..31).include?(day)
      return false unless year >= 1900 && year <= 2100

      Date.valid_date?(year, month, day)
    end
  end
end
