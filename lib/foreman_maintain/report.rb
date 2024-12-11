module ForemanMaintain
  class Report < Executable
    include Concerns::Logger
    include Concerns::SystemHelpers
    include Concerns::Metadata
    include Concerns::Finders

    attr_accessor :data

    def sql_count(sql, column: '*')
      feature(:foreman_database).query("SELECT COUNT(#{column}) FROM #{sql}").first['count'].to_i
    end

    def record_count!(key, sql, column: '*')
      self.data ||= {}
      logger.warn("Overwriting value of key '#{key}'") if self.data.key?(key)
      data["#{key}_count"] = sql_count(sql, column: column)
    rescue => e
      set_warn("#{key}: #{e.message}")
    end

    def sql_setting(name)
      sql = "SELECT value FROM settings WHERE name = '#{name}'"
      result = feature(:foreman_database).query(sql).first
      (result || {})['value']
    end

    def table_exists(table)
      sql_count("information_schema.tables WHERE table_name = '#{table}'").positive?
    end

    def run
      raise NotImplementedError
    end

    # internal method called by executor
    def __run__(execution)
      super
    rescue Error::Fail => e
      set_fail(e.message)
    rescue Error::Warn => e
      set_warn(e.message)
    end
  end
end
