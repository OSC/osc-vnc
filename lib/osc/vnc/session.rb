require 'yaml'
require 'fileutils'

require 'osc/vnc/listenable'

module OSC
  module VNC
    class Session
      include OSC::VNC::Listenable

      attr_accessor :batch, :cluster, :headers, :resources, :envvars
      attr_accessor :xstartup, :xlogout, :outdir, :options
      attr_accessor :pbsid, :host, :port, :display, :password

      DEFAULT_ARGS = {
        # Batch setup information
        batch: "oxymoron",
        cluster: "glenn",
        headers: {},
        resources: {},
        envvars: {},
        # Batch template options
        xstartup: nil,
        xlogout: nil,
        outdir: ENV['PWD'],
        options: {}
      }

      def initialize(args)
        args = DEFAULT_ARGS.merge(args)

        # Batch setup information
        @batch = args[:batch]
        @cluster = args[:cluster]
        @headers = args[:headers]
        @resources = args[:resources]
        @envvars = args[:envvars]

        # Batch template args
        @xstartup = args[:xstartup]
        @xlogout = args[:xlogout]
        @outdir = args[:outdir]
        @options = args[:options]
      end

      # Default headers are generated based on user input
      def headers
        {
          PBS::Torque::ATTR[:N] => "VNC_Job",
          PBS::Torque::ATTR[:o] => "#{outdir}/$PBS_JOBID.output",
          PBS::Torque::ATTR[:j] => "oe",
          PBS::Torque::ATTR[:S] => "/bin/bash"
        }.merge @headers
      end

      def run()
        raise ArgumentError, "xstartup script is not found" unless File.file?(xstartup)
        raise ArgumentError, "output directory is a file" if File.file?(outdir)

        # Create tcp listen server
        listen_server = nil
        if script_view.tcp_server?
          listen_server = create_listen
          addr, port, host, ip = listen_server.addr(:hostname)
          envvars.merge! LISTEN_HOST: host, LISTEN_PORT: port
        end

        # Make output directory if it doesn't already exist
        FileUtils.mkdir_p(outdir)

        # Use proper torque library
        if batch == "oxymoron"
          PBS::Torque.init lib: TORQUE_OXYMORON_LIB
        else
          PBS::Torque.init lib: TORQUE_COMPUTE_LIB
        end

        # Connect to server and submit job with proper PBS attributes
        batch_server = YAML.load_file("#{CONFIG_PATH}/batch.yml")[batch][cluster]
        c = PBS::Conn.new(server: batch_server)
        j = PBS::Job.new(conn: c)
        self.pbsid = j.submit(string: script_view.render, headers: headers, resources: resources, envvars: envvars).id

        # Get connection information right away if using tcp server
        _get_listen_conn_info(listen_server) if script_view.tcp_server?

        self
      end

      # Get connection info from file generated by PBS batch
      # job (read template/vnc.mustache)
      def refresh_conn_info
        conn_file = "#{outdir}/#{pbsid}.conn"
        raise RuntimeError, "connection file doesn't exist" unless File.file?(conn_file)
        _get_file_conn_info(conn_file)
      end

      def script_view
        ScriptView.new(batch: batch, cluster: cluster, xstartup: xstartup,
                       xlogout: xlogout, outdir: outdir, options: options)
      end


      # Get connection information from a file
      def _get_file_conn_info(file)
        _parse_conn_info File.read(file)
      end

      # Get connection information from a TCP listening server
      def _get_listen_conn_info(server)
        # Wait until VNC conn info is created by PBS batch script
        # Timeout after 30 seconds if no info is sent
        Timeout::timeout(30) { _parse_conn_info read_listen(server: server) }
      end

      # Parse out connection info from a string
      def _parse_conn_info(string)
        {:@host => 'Host', :@port => 'Port', :@display => 'Display', :@password => 'Pass'}.each do |key, value|
          instance_variable_set(key, /^#{value}: (.*)$/.match(string)[1])
          raise RuntimeError, "#{key} not specified by batch job" unless instance_variable_get(key)
        end
      end
    end
  end
end
