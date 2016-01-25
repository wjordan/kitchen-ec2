require 'kitchen/driver/aws/platform'

module Kitchen
  module Driver
    class Aws
      class Platform
        class Windows < Platform
          Platform.platforms['windows'] = self

          def username
            "administrator"
          end

          def image_search
            # windows-server-2012r2 == windows-2012r2
            version = self.version
            if version && version.start_with?("server")
              version = version.split("-", 2)[1]
            end
            case version
            when /^(\d+)r(\d+)$/
              version = "#{$1}-R#{$2}*"
            when nil, ""
              version = "*-RTM*"
            else
              version = "#{version}-RTM*"
            end

            search = {
              "owner-alias" => "amazon",
              "name" => "Windows_Server-#{version}-English-*-Base-*"
            }
            search["architecture"] = architecture if architecture
            search
          end

          def self.from_image(ec2, image)
            if image.name =~ /Windows/i
              if image.name =~ /(\b\d+)(\W*(r\d+))?\b/i
                version = $1 + $3.downcase
              end

              new(ec2, "windows", version, nil)
            end
          end
        end
      end
    end
  end
end
