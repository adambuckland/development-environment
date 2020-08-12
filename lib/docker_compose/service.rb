# Represents a single Docker service that from the architecture and allows
# configuring it with custom configuration
module DockerCompose
  class Service
    DEFAULTS = { build: false, environment: {} }.with_indifferent_access.freeze

    attr_reader :data

    def initialize(name, input_data)
      @name = name
      @data = input_data.deep_dup

      data[:environment] ||= {}
      data[:volumes] ||= []
    end

    def dependencies
      data[:depends_on] || []
    end

    def override(settings)
      settings = settings.reverse_merge(DEFAULTS)

      # Remove build from the final YAML if it's not requested
      data.delete :build if image? && settings[:build] == false

      # "build" might be a hash which will be deep merged
      settings.reject! { |k, v| k == "build" && [true, false].include?(v)}

      data[:environment] = merge_environment(data[:environment], settings.delete(:environment))

      # Prevent us from binding repos the user has not downloading which quickly breaks
      # everything since now an empty folder is mounted in place of the containers source
      data[:volumes].reject! { |v| DockerCompose::Volume.new(v).bind_source_missing? }

      data.deep_merge!(settings)

      cleanup
    end

    def cleanup
      data.delete(:volumes) if data[:volumes].empty?
      data.delete(:environment) if data[:environment].empty?
    end

    # might be in array or hash from from docker-compose
    def env_to_hash(environment)
      return environment if environment.is_a?(Hash)

      environment.to_h { |v| v.split("=", 2) }
    end

    def merge_environment(original, overlay)
      env_to_hash(original).merge(env_to_hash(overlay)).with_indifferent_access
    end

    def image?
      data[:image]
    end
  end
end