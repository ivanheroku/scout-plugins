# 
# Created by Eric Lindvall <eric@5stops.com>
#
# Taken from a script Eric wrote
# Modified by Ivan Makfinsky <ivan@heroku.com>
# Connect to postgres and retrieve number of open connections
# 20080909 v 0.1

require 'set'

class PostgresConnectionStatistics < Scout::Plugin
  def run
    begin
      require 'postgres'
    rescue LoadError => e
      return { :error => { :subject => "Unable to gather Postgres query statistics",
        :body => "Unable to find a postgres library. Please install the library to use this plugin" }
      }
    end

    user = @options['user'] || 'root'
    password, host, port, socket = @options.values_at %w(password host port socket)

    now = Time.now
    postgres = PGconn.connect(host, port, nil, nil, user, user, password)

    result = postgres.query('select datname, count(*) from pg_stat_activity group by datname;')

    rows = []
    total = 0
    result.each do |row| 
      rows << row
      total += row.last.to_i
    end
    postgres.close

    report = {}
    rows.each do |row|
      report[row.first] = row.last.to_i
    end

    report['total'] = total

    { :report => report, :memory => @memory }
  end

  private
  def calculate_counter(current_time, name, value)
    result = nil

    if @memory[name] && @memory[name].is_a?(Hash)
      last_time, last_value = @memory[name].values_at(:time, :value)

      # We won't log it if the value has wrapped
      if value >= last_value
        elapsed_seconds = last_time - current_time
        elapsed_seconds = 1 if elapsed_seconds < 1

        result = value - last_value

        if @options['calculate_per_second']
          result = result / elapsed_seconds.to_f
        end
      end
    end

    @memory[name] = { :time => current_time, :value => value }

    result
  end
end

