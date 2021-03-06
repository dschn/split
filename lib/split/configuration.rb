module Split
  class Configuration
    BOTS = {
      # Indexers
      "AdsBot-Google" => 'Google Adwords',
      'Baidu' => 'Chinese search engine',
      'Gigabot' => 'Gigabot spider',
      'Googlebot' => 'Google spider',
      'msnbot' => 'Microsoft bot',
      'rogerbot' => 'SeoMoz spider',
      'Slurp' => 'Yahoo spider',
      'Sogou' => 'Chinese search engine',
      "spider" => 'generic web spider',
      'WordPress' => 'WordPress spider',
      'ZIBB' => 'ZIBB spider',
      # HTTP libraries
      'Apache-HttpClient' => 'Java http library',
      'AppEngine-Google' => 'Google App Engine',
      "curl" => 'curl unix CLI http client',
      'ColdFusion' => 'ColdFusion http library',
      "EventMachine HttpClient" => 'Ruby http library',
      "Go http package" => 'Go http library',
      'Java' => 'Generic Java http library',
      'libwww-perl' => 'Perl client-server library loved by script kids',
      'lwp-trivial' => 'Another Perl library loved by script kids',
      "Python-urllib" => 'Python http library',
      "PycURL" => 'Python http library',
      "Test Certificate Info" => 'C http library?',
      "Wget" => 'wget unix CLI http client',
      # URL expanders / previewers
      'awe.sm' => 'Awe.sm URL expander',
      "bitlybot" => 'bit.ly bot',
      "facebookexternalhit" => 'facebook bot',
      'LongURL' => 'URL expander service',
      'Twitterbot' => 'Twitter URL expander',
      'UnwindFetch' => 'Gnip URL expander',
      # Uptime monitoring
      'check_http' => 'Nagios monitor',
      'NewRelicPinger' => 'NewRelic monitor',
      'Panopta' => 'Monitoring service',
      "Pingdom" => 'Pingdom monitoring',
      'SiteUptime' => 'Site monitoring services',
      # ???
      "DigitalPersona Fingerprint Software" => 'HP Fingerprint scanner',
      "ShowyouBot" => 'Showyou iOS app spider',
      'ZyBorg' => 'Zyborg? Hmmm....',
    }
    attr_accessor :robot_regex
    attr_accessor :ignore_ip_addresses
    attr_accessor :db_failover
    attr_accessor :db_failover_on_db_error
    attr_accessor :db_failover_allow_parameter_override
    attr_accessor :allow_multiple_experiments
    attr_accessor :enabled
    attr_accessor :experiments
    attr_accessor :persistence
    attr_accessor :algorithm

    def disabled?
      !enabled
    end

    def experiment_for(name)
      if normalized_experiments
        # TODO symbols
        normalized_experiments[name.to_sym]
      end
    end

    def metrics
      return @metrics if defined?(@metrics)
      @metrics = {}
      if self.experiments
        self.experiments.each do |key, value|
          metric_name = value_for(value, :metric).to_sym rescue nil
          if metric_name
            @metrics[metric_name] ||= []
            @metrics[metric_name] << Split::Experiment.new(key)
          end
        end
      end
      @metrics
    end

    def normalized_experiments
      if @experiments.nil?
        nil
      else
        experiment_config = {}
        @experiments.keys.each do |name|
          experiment_config[name.to_sym] = {}
        end

        @experiments.each do |experiment_name, settings|
          if alternatives = value_for(settings, :alternatives)
            experiment_config[experiment_name.to_sym][:alternatives] = normalize_alternatives(alternatives)
          end

          if goals = value_for(settings, :goals)
            experiment_config[experiment_name.to_sym][:goals] = goals
          end
        end

        experiment_config
      end
    end

    def normalize_alternatives(alternatives)
      given_probability, num_with_probability = alternatives.inject([0,0]) do |a,v|
        p, n = a
        if percent = value_for(v, :percent)
          [p + percent, n + 1]
        else
          a
        end
      end

      num_without_probability = alternatives.length - num_with_probability
      unassigned_probability = ((100.0 - given_probability) / num_without_probability / 100.0)

      if num_with_probability.nonzero?
        alternatives = alternatives.map do |v|
          if (name = value_for(v, :name)) && (percent = value_for(v, :percent))
            { name => percent / 100.0 }
          elsif name = value_for(v, :name)
            { name => unassigned_probability }
          else
            { v => unassigned_probability }
          end
        end

        [alternatives.shift, alternatives]
      else
        alternatives = alternatives.dup
        [alternatives.shift, alternatives]
      end
    end

    def initialize
      @robot_regex = /\b(#{BOTS.keys.join('|')})\b|^\W*$/i
      @ignore_ip_addresses = []
      @db_failover = false
      @db_failover_on_db_error = proc{|error|} # e.g. use Rails logger here
      @db_failover_allow_parameter_override = false
      @allow_multiple_experiments = false
      @enabled = true
      @experiments = {}
      @persistence = Split::Persistence::SessionAdapter
      @algorithm = Split::Algorithms::WeightedSample
    end

    private

    def value_for(hash, key)
      if hash.kind_of?(Hash)
        hash[key.to_s] || hash[key.to_sym]
      end
    end
  end
end
