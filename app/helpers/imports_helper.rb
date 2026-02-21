# frozen_string_literal: true

module ImportsHelper
  def status_badge_class(status)
    case status.to_s
    when "pending"
      "bg-neutral-100 text-neutral-600"
    when "in_progress"
      "bg-blue-100 text-blue-700"
    when "completed"
      "bg-green-100 text-green-700"
    when "failed"
      "bg-red-100 text-red-700"
    else
      "bg-neutral-100 text-neutral-600"
    end
  end
end
