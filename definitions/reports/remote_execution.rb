require 'csv'

module Checks
  module Report
    class RemoteExecution < ForemanMaintain::Report
      metadata do
        description 'Check how remote execution is used'
      end

      def run
        data = {}
        data['remote_execution_job_count'] = sql_count('job_invocations')
        data['remote_execution_job_with_future_scheduling_count'] = scheduling_count('future')
        # Multiple iterations of a single recurring job are counted as a single job
        data['remote_execution_job_with_recurring_scheduling_count'] = scheduling_count('recurring')
        data['remote_execution_job_with_dynamic_targeting_count'] = sql_count("job_invocations AS ji INNER JOIN targetings as t ON ji.targeting_id = t.id WHERE t.targeting_type = 'dynamic_query'")
        data['remote_execution_job_with_randomized_ordering_count'] = sql_count("job_invocations AS ji INNER JOIN targetings AS t ON ji.targeting_id = t.id WHERE t.randomized_ordering = 't'")
        data['remote_execution_job_with_concurrency_level_count'] = sql_count('job_invocations WHERE concurrency_level IS NOT NULL')
        data['remote_execution_job_with_execution_timeout_interval_count'] = sql_count('job_invocations WHERE execution_timeout_interval IS NOT NULL')

        # These attributes can be set at multiple levels, only the jobs where these attributes are set on the job level are counted
        data['remote_execution_job_with_time_to_pickup_count'] = sql_count('job_invocations WHERE time_to_pickup IS NOT NULL')
        data['remote_execution_job_with_ssh_user_count'] = sql_count('job_invocations WHERE ssh_user IS NOT NULL')

        data['remote_execution_proxy_settings'] = name_list("settings WHERE name IN ('remote_execution_fallback_proxy', 'remote_execution_global_proxy', 'remote_execution_prefer_registered_through_proxy')")
        data['remote_execution_cockpit_enabled'] = sql_count("settings WHERE name = 'remote_execution_cockpit_url'") > 0

        # Beware: if anyone ever changed the feature to use a custom template and then back to the original one, it will still show in here
        data['remote_execution_customized_features'] = name_list("remote_execution_features AS rfe INNER JOIN audits AS a ON a.auditable_type = 'RemoteExecutionFeature' AND rfe.id = a.auditable_id WHERE a.username != 'Anonymous Admin' AND a.action = 'update'")

        data['remote_execution_custom_script_template_count'] = sql_count("templates WHERE type = 'JobTemplate' AND provider_type IN ('SSH', 'script') AND templates.default = 'f'")
        data['remote_execution_custom_ansible_template_count'] = sql_count("templates WHERE type = 'JobTemplate' AND provider_type = 'Ansible' AND templates.default = 'f'")

        self.data = data
      end

      private

      def sql_count(suffix)
        super "SELECT COUNT(*) FROM #{suffix}"
      end

      def name_list(suffix)
        eature(:foreman_database).query("SELECT name FROM #{suffix}").map { |r| r['name'] }.to_csv.chomp
      end

      def scheduling_count(type)
        sql = <<~SQL
          foreman_tasks_triggerings AS ftt
          WHERE
            ftt.mode = '#{type}'
            AND ftt.id IN (SELECT triggering_id FROM job_invocations)
        SQL

        sql_count(sql)
      end
    end
  end
end
