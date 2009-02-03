class DiskUsage < Scout::Plugin

  # the Disk Freespace RegEx
  DF_RE = /\A\s*(\S.*?)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*\z/

  # Parses the file systems lines according to the Regular Expression
  # DF_RE.
  # 
  # normal line ex:
  # /dev/disk0s2   233Gi   55Gi  177Gi    24%    /
  
  # multi-line ex:
  # /dev/mapper/VolGroup00-LogVol00
  #                        29G   25G  2.5G  92% /
  #
  # Updates thanks to Pedro Belo 20081113
  #

  def parse_file_systems(io, &line_handler)
    line_handler ||= lambda { |row| pp row }
    headers      =   nil

    row = ""
    io.each do |line|
      if headers.nil? and line =~ /\AFilesystem/
        headers = line.split(" ", 6).map { |h| h.strip }
      else
        row << line
        if row =~  DF_RE
          fields = $~.captures
          line_handler[headers ? Hash[*headers.zip(fields).flatten] : fields]
          row = ""
        end
      end
    end
  end
  
  def build_report
    df_command   = @options["command"] || "df -h"
    df_output    = `#{df_command}`
    
    report       = {:report => Hash.new, :alerts => Array.new}
        
    df_lines = []
    parse_file_systems(df_output) { |row| df_lines << row }
    
    # if the user specified a filesystem use that
    df_line = nil
    if @options["filesystem"]
      df_lines.each do |line|
        if line.has_value?(@options["filesystem"])
          df_line = line
        end
      end
    end
    
    # else capture all filesystems
	 puts df_lines.inspect
	 df_line ||= df_lines.inject({}) do |h, row|
	 	row.each do |header, value|
			next if header == 'Mounted on'
			h["#{header} mounted on #{row['Mounted on']}"] = value
		end
		h
	end
      
    df_line.each do |name, value|
      report[:report][name.downcase.strip.to_sym] = value
    end
    
    max = @options["max_capacity"].to_i

	 if max > 0
		report[:report].each { |key, value|
			if key.to_s.match("use%") and value.to_i > max
				report[:alerts] << { :subject => "Maximum Capacity Exceeded " +
												"(#{report[:report][key]})" }
			end
		}
    else
      if max > 0 and report[:report][:capacity].to_i > max
        report[:alerts] << { :subject => "Maximum Capacity Exceeded " +
                                       "(#{report[:report][:capacity]})" }
      end
    end
    report
  rescue
    { :error => { :subject => "Couldn't use `df` as expected.",
                  :body    => $!.message } }
  end
end
