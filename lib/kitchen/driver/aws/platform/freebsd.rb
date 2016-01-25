require 'kitchen/driver/aws/platform'

module Kitchen
  module Driver
    class Aws
      class Platform
        class Freebsd < Platform
          Platform.platforms["freebsd"] = self

          def username
            "ec2-user"
          end

          def image_search
            search = {
              "owner-id" => "118940168514",
              "name" => "FreeBSD/EC2 #{version}*-RELEASE*"
            }
            search["architecture"] = architecture if architecture
            search
          end

          def self.from_image(ec2, image)
            if image.name =~ /freebsd\D*(\d+(\.\d+)?)?/i
              new(ec2, "freebsd", $1, nil)
            end
          end
        end
      end
    end
  end
end
