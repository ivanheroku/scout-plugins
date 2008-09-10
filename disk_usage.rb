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
  def parse_file_systems(io, &line_handler)
    line_handler ||= lambda { |row| pp row }
    headers      =   nil

    row = ""
    io.each do |line|
      if headers.nil? and line =~ /\AFilesystem/
        headers = line.split(" ", 6)
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
  
  def run
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
    
    # else just use the first line
    df_line ||= df_lines.first
      
    df_line.each do |name, value|
      report[:report][name.downcase.strip.to_sym] = value
    end
    
    max = @options["max_capacity"].to_i

    if report[:report][:capacity].nil?
      if max > 0 and report[:report][:"use%"].to_i > max
        report[:alerts] << { :subject => "Maximum Capacity Exceeded " +
                                       "(#{report[:report][:"use%"]})" }
      end
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
