#
# Copyright (C) 2018 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class DeveloperKeyAccountBinding < ApplicationRecord
  DEFAULT_STATE = 'allow'.freeze

  belongs_to :account
  belongs_to :developer_key

  validates :account, :developer_key, presence: true
  validates :workflow_state, inclusion: { in: ['off', 'allow', 'on'] }

  before_validation :infer_workflow_state

  # Find a DeveloperKeyAccountBinding in order of account_ids. The search for a binding will
  # be prioritized by the order of account_ids. If a binding is found for the first account
  # that binding will be returned, otherwise the next account will be searched and so on.
  #
  # By default only bindings with a workflow set to “on” or “off” are considered. To include
  # bindings with workflow state “allow” set the explicitly_set parameter to false.
  #
  # For example consider four accounts with ids 1, 2, 3, and 4. Accounts 2, 3, and 4 have a binding
  # with the developer key. The workflow state of the binding for account 2 is "allow." The
  # workflow state of the binding for account 3 is "off." The workflow state of the binding for
  # account 4 is "on."
  #
  # find_in_account_priority([1, 2, 3, 4], developer_key.id) would return the binding for
  # account 3.
  #
  # find_in_account_priority([1, 2, 3, 4], developer_key.id, false) would return the binding for
  # account 2.
  def self.find_in_account_priority(account_ids, developer_key_id, explicitly_set = true)
    raise 'Account ids must be integers' if account_ids.any? { |id| !id.is_a?(Integer) }
    account_ids_string = "{#{account_ids.join(',')}}"
    binding_id = DeveloperKeyAccountBinding.connection.select_values(<<-SQL)
      SELECT b.*
      FROM
          unnest('#{account_ids_string}'::int8[]) WITH ordinality AS i (id, ord)
          JOIN #{DeveloperKeyAccountBinding.quoted_table_name} b ON i.id = b.account_id
      WHERE
          b."developer_key_id" = #{developer_key_id}
      AND
          b."workflow_state" <> '#{explicitly_set.present? ? DEFAULT_STATE : "NULL"}'
      ORDER BY i.ord ASC LIMIT 1
    SQL
    self.find_by(id: binding_id)
  end

  private

  def infer_workflow_state
    self.workflow_state ||= DEFAULT_STATE
  end
end
