# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryParser do
  describe ".parse" do
    context "with text only" do
      it "returns text without date range" do
        result = described_class.parse("birthday party")
        expect(result[:text]).to eq("birthday party")
        expect(result[:date_range]).to be_nil
      end

      it "handles empty query" do
        result = described_class.parse("")
        expect(result[:text]).to be_nil
        expect(result[:date_range]).to be_nil
      end

      it "handles nil query" do
        result = described_class.parse(nil)
        expect(result[:text]).to be_nil
        expect(result[:date_range]).to be_nil
      end
    end

    context "with full dates" do
      it "parses DD-MM-YYYY format" do
        result = described_class.parse("11-04-1979")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
        expect(result[:text]).to be_nil
      end

      it "parses DD/MM/YYYY format" do
        result = described_class.parse("11/04/1979")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
      end

      it "parses YYYY-MM-DD (ISO) format" do
        result = described_class.parse("1979-04-11")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
      end

      it "parses '11th April 1979' format" do
        result = described_class.parse("11th April 1979")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
      end

      it "parses '11 April 1979' format" do
        result = described_class.parse("11 April 1979")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
      end

      it "parses 'April 11, 1979' format" do
        result = described_class.parse("April 11, 1979")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
      end

      it "parses 'April 11 1979' format" do
        result = described_class.parse("April 11 1979")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
      end
    end

    context "with month and year" do
      it "parses 'August 1998'" do
        result = described_class.parse("August 1998")
        expect(result[:date_range]).to eq(
          Date.new(1998, 8, 1).beginning_of_day..Date.new(1998, 8, 31).end_of_day
        )
      end

      it "parses 'Aug 98' (two digit year)" do
        result = described_class.parse("Aug 98")
        expect(result[:date_range]).to eq(
          Date.new(1998, 8, 1).beginning_of_day..Date.new(1998, 8, 31).end_of_day
        )
      end

      it "parses 'December 05' as 2005" do
        result = described_class.parse("December 05")
        expect(result[:date_range]).to eq(
          Date.new(2005, 12, 1).beginning_of_day..Date.new(2005, 12, 31).end_of_day
        )
      end
    end

    context "with year only" do
      it "parses four digit year '1998'" do
        result = described_class.parse("1998")
        expect(result[:date_range]).to eq(
          Date.new(1998, 1, 1).beginning_of_day..Date.new(1998, 12, 31).end_of_day
        )
      end

      it "parses apostrophe year ''98'" do
        result = described_class.parse("'98")
        expect(result[:date_range]).to eq(
          Date.new(1998, 1, 1).beginning_of_day..Date.new(1998, 12, 31).end_of_day
        )
      end

      it "parses '2020'" do
        result = described_class.parse("2020")
        expect(result[:date_range]).to eq(
          Date.new(2020, 1, 1).beginning_of_day..Date.new(2020, 12, 31).end_of_day
        )
      end
    end

    context "with mixed text and dates" do
      it "extracts date and keeps remaining text" do
        result = described_class.parse("birthday party August 1998")
        expect(result[:text]).to eq("birthday party")
        expect(result[:date_range]).to eq(
          Date.new(1998, 8, 1).beginning_of_day..Date.new(1998, 8, 31).end_of_day
        )
      end

      it "extracts full date and keeps remaining text" do
        result = described_class.parse("wedding 11-04-1979 celebration")
        expect(result[:text]).to eq("wedding celebration")
        expect(result[:date_range]).to eq(Date.new(1979, 4, 11).all_day)
      end
    end

    context "with month only" do
      it "parses month name and uses current/recent year" do
        result = described_class.parse("August")
        expect(result[:date_range]).not_to be_nil

        # Should be August of current year or last year
        range_start = result[:date_range].begin.to_date
        expect(range_start.month).to eq(8)
        expect(range_start.day).to eq(1)
      end
    end

    context "edge cases" do
      it "handles abbreviated months" do
        result = described_class.parse("Sept 99")
        expect(result[:date_range]).to eq(
          Date.new(1999, 9, 1).beginning_of_day..Date.new(1999, 9, 30).end_of_day
        )
      end

      it "is case insensitive" do
        result = described_class.parse("AUGUST 1998")
        expect(result[:date_range]).to eq(
          Date.new(1998, 8, 1).beginning_of_day..Date.new(1998, 8, 31).end_of_day
        )
      end
    end
  end
end
