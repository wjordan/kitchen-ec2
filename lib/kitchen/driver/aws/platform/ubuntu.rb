require 'kitchen/driver/aws/platform'

module Kitchen
  module Driver
    class Aws
      class Platform
        class Ubuntu < Platform
          Platform.platforms['ubuntu'] = self

          def username
            "ubuntu"
          end

          def image_search
            search = {
              "owner-id" => "099720109477",
              "name" => "ubuntu/images/*/ubuntu-*-#{version}*"
            }
            search["architecture"] = architecture if architecture
            search
          end

          def self.from_image(ec2, image)
            if image.name =~ /ubuntu\D*(\d+(\.\d+)?)?/i
              new(ec2, "ubuntu", $1, nil)
            end
          end
        end
      end
    end
  end
end
