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
    password, host, port, dbname = @options.values_at %w(password host port dbname)

    now = Time.now
    postgres = PGconn.connect(host, port, nil, nil, dbname, user, password)

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

end

