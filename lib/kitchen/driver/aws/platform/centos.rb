require "kitchen/driver/aws/platform"

module Kitchen
  module Driver
    class Aws
      class Platform
        # https://wiki.centos.org/Cloud/AWS
        class Centos < Platform
          Platform.platforms["centos"] = self

          def username
            "root"
          end

          def image_search
            if version && version.to_f < 7
              name = "CentOS-#{version}*-GA-*"
            else
              name = "CentOS Linux #{version}*"
            end

            search = {
              "owner-alias" => "aws-marketplace",
              "name" => name
            }
            search["architecture"] = architecture if architecture
            search
          end

          def self.from_image(ec2, image)
            if image.name =~ /centos\D*(\d+(\.\d+)?)?/i
              new(ec2, name, $1, nil)
            end
          end
        end
      end
    end
  end
end
