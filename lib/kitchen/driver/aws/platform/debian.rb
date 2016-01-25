require "kitchen/driver/aws/platform"

module Kitchen
  module Driver
    class Aws
      class Platform
        # https://wiki.debian.org/Cloud/AmazonEC2Image
        class Debian < Platform
          Platform.platforms["debian"] = self

          DEBIAN_CODENAMES = {
            "8" => "jessie",
            "7" => "wheezy",
            "6" => "squeeze"
          }

          def username
            "admin"
          end

          def codename
            version ? DEBIAN_CODENAMES[version] : DEBIAN_CODENAMES.values.first
          end

          def image_search
            search = {
              "owner-id" => "379101102735",
              "name" => "debian-#{codename}-*"
            }
            search["architecture"] = architecture if architecture
            search
          end

          def self.from_image(ec2, image)
            if image.name =~ /debian\D*(\d+|#{DEBIAN_CODENAMES.values.join("|")}\b)?/i
              new(ec2, name, $1, nil)
            end
          end
        end
      end
    end
  end
end
