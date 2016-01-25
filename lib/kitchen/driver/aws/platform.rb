module Kitchen
  module Driver
    class Aws
      class Platform
        def initialize(ec2, name, version, architecture)
          @ec2 = ec2
          @name = name
          @version = version
          @architecture = architecture
        end

        attr_reader :ec2
        attr_reader :name
        attr_reader :version
        attr_reader :architecture

        #
        # Find the best matching image for the given image search
        #
        def find_image(ec2, image_search)
          # Convert to ec2 search format (pairs of name+values)
          filters = image_search.map do |key, value|
            { name: key.to_s, values: Array(value).map { |v| v.to_s } }
          end

          # We prefer most recent first
          images = ec2.resource.images(:filters => filters).sort do |ami1, ami2|
            Time.parse(ami2.creation_date) <=> Time.parse(ami1.creation_date)
          end
          # We prefer x86_64 over i386 (if available)
          images = prefer(images) { |image| image.architecture == :x86_64 }
          # We prefer gp2 (SSD) (if available)
          images = prefer(images) { |image| image.block_device_mappings.any? { |b| b.device_name == image.root_device_name && b.ebs && b.ebs.volume_type == "gp2" } }
          # We prefer ebs over instance_store (if available)
          images = prefer(images) { |image| image.root_device_type == "ebs" }
          # We prefer hvm (the modern standard)
          images = prefer(images) { |image| image.virtualization_type == "hvm" }

          # Grab the best match
          images.first && images.first.id
        end

        def self.platforms
          @platforms ||= {}
        end

        # Not supported yet: aix mac_os_x nexus solaris

        ARCHITECTURE = %w(x86_64 i386 i86pc sun4v powerpc)

        def self.from_platform_string(ec2, platform_string)
          platform, version, architecture = parse_platform_string(platform_string)
          if platform && platforms[platform]
            platforms[platform].new(ec2, platform, version, architecture)
          end
        end

        def self.from_image(ec2, image)
          platforms.each_value do |platform|
            result = platform.from_image(ec2, image)
            return result if result
          end
          nil
        end

        protected

        def prefer(images, &block)
          # Put the matching ones *before* the non-matching ones.
          matching, non_matching = images.partition(&block)
          matching + non_matching
        end

        private

        def self.parse_platform_string(platform_string)
          platform, version = platform_string.split("-", 2)

          # If the right side is a valid architecture, use it as such
          # i.e. debian-i386 or windows-server-2012r2-i386
          if version && ARCHITECTURE.include?(version.split("-")[-1])
            # server-2012r2-i386 -> server-2012r2, -, i386
            version, dash, architecture = version.rpartition("-")
            version = nil if version == ""
          end

          [ platform, version, architecture ]
        end
      end
    end
  end
end
