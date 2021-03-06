# A utility module to deal with cassandra storage
# config YAML and other helper methods.
#
# Cookbook Name:: cassandra
# Library:: cassandra_util
#
# Copyright 2016, Appranix.

module Cassandra

  module Util
    require 'json'
    require 'yaml'

    include Chef::Mixin::ShellOut

    # Checks if the YAML config directives are supported.
    # Applicable only if versions of Cassandra >= 1.2 and
    # has a non empty config directive map.
    #
    def conf_directive_supported?
      ci = node.workorder.rfcCi.ciAttributes
      ver = ci.version.to_f
      cfg = ci.config_directives if ci.has_key?("config_directives")
      cassandra_supported?(ver) && !cfg.nil? && !cfg.empty?
    end

    # Checks if the Log4j config directives are supported.
    # Applicable only if versions of Cassandra >= 1.2 and
    # has a non empty config directive map.
    #
    def log4j_directive_supported?
      ci = node.workorder.rfcCi.ciAttributes
      cfg = ci.log4j_directives if ci.has_key?("log4j_directives")
      !cfg.nil? && !cfg.empty?
    end

    # Merge cassandra config directives to the given Cassandra
    # storage config YAML file. The method will error out if
    # it couldn't find the yaml config file.
    #
    # Note : Right now there is no way to preserve the comments in
    # YAML when you do the modification using libraries. Normally
    # this method call would be guarded by ::conf_directive_supported?
    #
    #  Eg:  merge_conf_directives(file, cfg) if conf_directive_supported?
    #
    # @param  config_file:: cassandra yaml config file
    # @param  cfg:: Configuration directives map.
    #
    def merge_conf_directives(config_file, cfg)
      Chef::Log.info "YAML config file: #{config_file}, conf directive entries: #{cfg}"
      # Always backup
      bak_file = config_file.sub('.yaml', '_template.yaml')
      File.rename(config_file, bak_file)
      yaml = YAML::load_file(bak_file)
      puts cfg

      cfg.each_key { |key|
        if key == "data_file_directories"
          val = parse_json(cfg[key]).split(",")
        elsif key == "seed_provider"
          val = cfg[key]
        else
          val = parse_json(cfg[key])
        end
        yaml[key] = val
      }
      Chef::Log.info "Merged cassandra YAML config: #{yaml.to_yaml}"

      File.open(config_file, 'w') { |f|
        f.write <<-EOF
# Cassandra storage config YAML
#
# NOTE:
#   See http://wiki.apache.org/cassandra/StorageConfiguration
#   or  #{bak_file} file for full
#   explanations of configuration directives
# /NOTE
#
# Auto generated by Cassandra cookbook
        EOF
        f.write yaml.to_yaml
        Chef::Log.info "Saved YAML config to #{config_file}"
      }
    end

    # Checks if the cassandra version is
    # supported for YAML config directives.
    #
    # @param ver:: cassandra version
    #
    def cassandra_supported?(ver)
      ver >= 1.2
    end


    # Checks whether the given string is a valid json or not.
    #
    # @param json:: input json string
    #
    def valid_json?(json)
      begin
        JSON.parse(json)
        return true
      rescue Exception => e
        return false
      end
    end

    # Returns the parsed json object if the input string is a valid json, else
    # returns the input by doing the type conversion. Currently boolean, float,
    # int and string types are supported. The type conversion is required for
    # yaml since the input from UI would always be string.
    #
    # @param json:: input json string
    #
    def parse_json (json)
      begin
        return JSON.parse(json)
      rescue Exception => e
        # Assuming it would be string.
        # Boolean type
        return true if  json =~ (/^(true)$/i)
        return false if  json =~ (/^(false)$/i)
        # Fixnum type
        return json.to_i if  (json.to_i.to_s == json)
        # Float type
        return json.to_f if  (json.to_f.to_s == json)
        return json
      end
    end

    #returns array of seeds. array includes first seed_count no. of IPs from each clouds (sorted as per ciName).
    #If seed_count > no. of computes in cloud then include all IPs from the cloud.
    #if $ip_exclude will be excluded from the resulting array (required in 'replace')
    def self.discover_seed_nodes(node, seed_count, ip_exclude=nil)
      computes = node.workorder.payLoad.has_key?("RequiresComputes") ? node.workorder.payLoad.RequiresComputes : node.workorder.payLoad.computes
      return [computes.first["ciAttributes"]["private_ip"]] if (computes.size == 1)
      cloud_computes = {}
      computes.each do |compute|
        next if compute[:ciAttributes][:private_ip].nil? || compute[:ciAttributes][:private_ip].empty? || compute[:ciAttributes][:private_ip] == ip_exclude
        cloud_id = compute[:ciName].split('-').reverse[1]
        computeList = cloud_computes[cloud_id] == nil ? [] : cloud_computes[cloud_id]
        computeList.push compute
        cloud_computes[cloud_id] = computeList
      end
      seeds = []
      cloud_computes.each do |key, value|
        sorted_computes = value.sort_by {|obj| obj.ciName}
        slected_computes = value.size >= seed_count ? sorted_computes.first(seed_count) : sorted_computes.first(value.size)
        slected_computes.each do |s|
          seeds.push s["ciAttributes"]["private_ip"]
        end
      end
      return seeds
    end

   # Returns hash of the key, value pairs from the propery file
   def load_properties(properties_filename)
      properties = {}
      File.open(properties_filename, 'r') do |properties_file|
        properties_file.read.each_line do |line|
          line.strip!
          if (line[0] != ?# and line[0] != ?=)
            Chef::Log.info "line : #{line}"
            i = line.index('=')
            if (i)
              properties[line[0..i - 1].strip] = line[i + 1..-1].strip
            end
          end
        end
      end
      return properties
   end

   # Merge log4j property file with the config provided
   def merge_log4j_directives(log4j_file, cfg)
      Chef::Log.info "Log4j file: #{log4j_file}, log4j directive entries: #{cfg}"
      # Always backup
      bak_file = log4j_file.sub('.properties', '_template.properties')
      File.rename(log4j_file, bak_file)
      log_props = load_properties(bak_file)
      cfg.each_key { |key|
        val = parse_json(cfg[key])
        log_props[key] = val
      }
      Chef::Log.info "Merged cassandra log4j : #{log_props.to_yaml}"
      File.open(log4j_file, 'w') { |f|
        log_props.each {|key,value| f.puts "#{key}=#{value}\n" }
        Chef::Log.info "Saved Log4j config to #{log4j_file}"
      }
  end

  #Check if the cassandra is running, allow #seconds to start running
  def cassandra_running(seconds=120)
    begin
      Timeout::timeout(seconds) do
        running = false
        while !running do
          cmd = "service cassandra status 2>&1"
          Chef::Log.info(cmd)
          result  = `#{cmd}`
            if $? == 0
              running = true
              break
            end
            sleep 5
          end
          return running
        end
      rescue Timeout::Error
        return false
      end
    end

    def port_open?(ip, port=9160)
      begin
        cmd = "service cassandra status 2>&1"
      result  = `#{cmd}`
      if $? == 0
        Chef::Log.info("Check if port open on #{ip}")
        TCPSocket.new(ip, port).close
        return true
      else
        puts "***FAULT:FATAL=Cassandra isn't running on #{ip}"
        e = Exception.new("no backtrace")
        e.set_backtrace("")
        raise e
      end
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
      sleep 5
      retry
    end
  end

  def cluster_normal?(node)
    yaml_file = '/etc/cassandra/cassandra.yaml'
    nodetool = "nodetool"
    if node.platform =~ /redhat|centos/
      yaml_file = "/opt/cassandra/conf/cassandra.yaml"
      nodetool = "/opt/cassandra/bin/nodetool"
    end
    yaml = YAML::load_file(yaml_file)
    seeds = yaml['seed_provider'][0]['parameters'][0]['seeds'].split(',')
    rows = `#{nodetool} -h #{seeds[0]} status`.split("\n")
    Chef::Log.info("ring rows: #{rows.inspect}")
    rows.each do |row|
      Chef::Log.info("row: #{row}")
      parts = row.split(" ")
      next unless parts.size == 8
      next unless IPAddress.valid? parts[1]
      if parts[0] !~ /UN|DN/ then
          Chef::Log.info("Node #{parts[1]} is in #{parts[0]} state")
          return false
      end
    end
    return true
  end

  def self.sorted_ci_names(node, action)
     computes = node.workorder.payLoad.has_key?("RequiresComputes") ? node.workorder.payLoad.RequiresComputes : node.workorder.payLoad.computes
     ci_cloud_ids = []
     computes.each do |compute|
       next if !compute.has_key?"rfcAction" || compute[:rfcAction].nil? || compute[:rfcAction] != action
       ci_cloud_ids.push compute[:ciName].split('-',2)[1]
     end
     return ci_cloud_ids.sort! { |x,y| (y.split('-')[1] == x.split('-')[1]) ? y.split('-')[0].to_i <=> x.split('-')[0].to_i : y.split('-')[1].to_i <=> x.split('-')[1].to_i }.reverse
    end
  end

end
