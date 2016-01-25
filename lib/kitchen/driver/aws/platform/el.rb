require 'kitchen/driver/aws/platform'

module Kitchen
  module Driver
    class Aws
      class Platform
        # https://aws.amazon.com/blogs/aws/now-available-red-hat-enterprise-linux-64-amis/
        class El < Platform
          Platform.platforms["el"] = self

          def username
            (version && version.to_f < 6.4) ? "root" : "ec2-user"
          end

          def image_search
            search = {
              "owner-id" => "309956199498",
              "name" => "RHEL-#{version}*"
            }
            search["architecture"] = architecture if architecture
            search
          end

          def self.from_image(ec2, image)
            if image.name =~ /rhel\D*(\d+(\.\d+)?)?/i
              new(ec2, name, $1, nil)
            end
          end
        end
      end
    end
  end
end
