# The usage ledger. Every gateway call writes one row — the seed of what hob's
# usage plane eventually owns for the whole household. (Ported from kat.)
class LLMUsage < ApplicationRecord
  # status values:
  #   success      — call completed
  #   refused      — 200 but the model declined the task (prose where structured
  #                  JSON was expected); countable rather than masquerading as work
  #   rate_limited — hit provider rate limits
  #   error        — call failed
  STATUSES = %w[success refused rate_limited error].freeze

  validates :operation, presence: true
  validates :model, presence: true
  validates :input_tokens,  numericality: { greater_than_or_equal_to: 0 }
  validates :output_tokens, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent,        -> { order(created_at: :desc) }
  scope :successful,    -> { where(status: "success") }
  scope :refused,       -> { where(status: "refused") }
  scope :failed,        -> { where(status: %w[error rate_limited]) }
  scope :for_operation, ->(op)   { where(operation: op) }
  scope :for_role,      ->(role) { where(role: role) }
  scope :today,         -> { where(created_at: Time.current.beginning_of_day..) }

  def total_tokens
    input_tokens + output_tokens
  end

  class << self
    def total_cost
      successful.sum(:cost) || 0
    end

    def stats
      {
        total_calls:      count,
        successful_calls: successful.count,
        failed_calls:     failed.count,
        total_cost:       total_cost.to_f.round(4),
        by_role:          successful.group(:role).sum(:cost).transform_values { |c| c.to_f.round(4) }
      }
    end
  end
end
