require 'kitchen/driver/aws/platform'

module Kitchen
  module Driver
    class Aws
      class Platform
        class Fedora < Platform
          Platform.platforms["fedora"] = self

          def username
            "ec2-user"
          end

          def image_search
            search = {
              "owner-id" => "125523088429",
              "name" => version ? "Fedora-Cloud-Base-#{version}-*" : "Fedora-Cloud-Base-*"
            }
            search["architecture"] = architecture if architecture
            search
          end

          def self.from_image(ec2, image)
            if image.name =~ /fedora\D*(\d+(\.\d+)?)?/i
              new(ec2, "fedora", $1, nil)
            end
          end
        end
      end
    end
  end
end
