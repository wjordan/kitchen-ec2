require "kitchen/driver/ec2"
require "kitchen/provisioner/dummy"
require "kitchen/transport/dummy"
require "kitchen/verifier/dummy"

describe Kitchen::Driver::Ec2 do

  class FakeImage
    def self.next_ami
      @n ||= 0
      @n += 1
      [ sprintf("ami-%08x", @n), Time.now + @n ]
    end

    def initialize(name: "foo", creation_date: nil, architecture: :x86_64, volume_type: "gp2", root_device_type: "ebs", virtualization_type: "hvm")
      @id, @creation_date = FakeImage.next_ami
      @creation_date = creation_date if creation_date
      @creation_date = @creation_date.strftime("%F %T")
      @architecture = architecture
      @volume_type = volume_type
      @root_device_type = root_device_type
      @virtualization_type = virtualization_type
      @root_device_name = "root"
      @device_name = "root"
    end
    attr_reader :id
    attr_reader :name
    attr_reader :creation_date
    attr_reader :architecture
    attr_reader :volume_type
    attr_reader :root_device_type
    attr_reader :virtualization_type
    attr_reader :root_device_name
    attr_reader :device_name

    def block_device_mappings
      [ self ]
    end
    def ebs
      self
    end
  end

  describe "#image_id" do
    PLATFORM_SEARCHES = {
      "centos" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: [ "CentOS Linux *" ] },
      ],
      "centos-8" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: [ "CentOS Linux 8*" ] },
      ],
      "centos-7.1" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: [ "CentOS Linux 7.1*" ] },
      ],
      "centos-6" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: %w{CentOS-6*-GA-*} },
      ],
      "centos-6.1" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: %w{CentOS-6.1*-GA-*} },
      ],
      "centos-x86_64" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: [ "CentOS Linux *" ] },
        { name: "architecture", values: %w(x86_64) },
      ],
      "centos-6-x86_64" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: %w{CentOS-6*-GA-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
      "centos-7.1-x86_64" => [
        { name: "owner-alias", values: %w{aws-marketplace} },
        { name: "name", values: [ "CentOS Linux 7.1*" ] },
        { name: "architecture", values: %w(x86_64) },
      ],

      "debian" => [
        { name: "owner-id", values: %w{379101102735} },
        { name: "name", values: %w{debian-jessie-*} },
      ],
      "debian-8" => [
        { name: "owner-id", values: %w{379101102735} },
        { name: "name", values: %w{debian-jessie-*} },
      ],
      "debian-7" => [
        { name: "owner-id", values: %w{379101102735} },
        { name: "name", values: %w{debian-wheezy-*} },
      ],
      "debian-6" => [
        { name: "owner-id", values: %w{379101102735} },
        { name: "name", values: %w{debian-squeeze-*} },
      ],
      "debian-x86_64" => [
        { name: "owner-id", values: %w{379101102735} },
        { name: "name", values: %w{debian-jessie-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
      "debian-6-x86_64" => [
        { name: "owner-id", values: %w{379101102735} },
        { name: "name", values: %w{debian-squeeze-*} },
        { name: "architecture", values: %w(x86_64) },
      ],

      "el" => [
        { name: "owner-id", values: %w{309956199498} },
        { name: "name", values: %w{RHEL-*} },
      ],
      "el-6" => [
        { name: "owner-id", values: %w{309956199498} },
        { name: "name", values: %w{RHEL-6*} },
      ],
      "el-7.1" => [
        { name: "owner-id", values: %w{309956199498} },
        { name: "name", values: %w{RHEL-7.1*} },
      ],
      "el-x86_64" => [
        { name: "owner-id", values: %w{309956199498} },
        { name: "name", values: %w{RHEL-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
      "el-6-x86_64" => [
        { name: "owner-id", values: %w{309956199498} },
        { name: "name", values: %w{RHEL-6*} },
        { name: "architecture", values: %w(x86_64) },
      ],

      "fedora" => [
        { name: "owner-id", values: %w{125523088429} },
        { name: "name", values: %w{Fedora-Cloud-Base-*} },
      ],
      "fedora-21" => [
        { name: "owner-id", values: %w{125523088429} },
        { name: "name", values: %w{Fedora-Cloud-Base-21-*} },
      ],
      "fedora-x86_64" => [
        { name: "owner-id", values: %w{125523088429} },
        { name: "name", values: %w{Fedora-Cloud-Base-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
      "fedora-21-x86_64" => [
        { name: "owner-id", values: %w{125523088429} },
        { name: "name", values: %w{Fedora-Cloud-Base-21-*} },
        { name: "architecture", values: %w(x86_64) },
      ],

      "freebsd" => [
        { name: "owner-id", values: %w{118940168514} },
        { name: "name", values: [ "FreeBSD/EC2 *-RELEASE*" ] },
      ],
      "freebsd-10" => [
        { name: "owner-id", values: %w{118940168514} },
        { name: "name", values: [ "FreeBSD/EC2 10*-RELEASE*" ] },
      ],
      "freebsd-10.1" => [
        { name: "owner-id", values: %w{118940168514} },
        { name: "name", values: [ "FreeBSD/EC2 10.1*-RELEASE*" ] },
      ],
      "freebsd-x86_64" => [
        { name: "owner-id", values: %w{118940168514} },
        { name: "name", values: [ "FreeBSD/EC2 *-RELEASE*" ] },
        { name: "architecture", values: %w(x86_64) },
      ],
      "freebsd-10-x86_64" => [
        { name: "owner-id", values: %w{118940168514} },
        { name: "name", values: [ "FreeBSD/EC2 10*-RELEASE*" ] },
        { name: "architecture", values: %w(x86_64) },
      ],

      "ubuntu" => [
        { name: "owner-id", values: %w{099720109477} },
        { name: "name", values: %w{ubuntu/images/*/ubuntu-*-*} },
      ],
      "ubuntu-14" => [
        { name: "owner-id", values: %w{099720109477} },
        { name: "name", values: %w{ubuntu/images/*/ubuntu-*-14*} },
      ],
      "ubuntu-12.04" => [
        { name: "owner-id", values: %w{099720109477} },
        { name: "name", values: %w{ubuntu/images/*/ubuntu-*-12.04*} },
      ],
      "ubuntu-x86_64" => [
        { name: "owner-id", values: %w{099720109477} },
        { name: "name", values: %w{ubuntu/images/*/ubuntu-*-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
      "ubuntu-14-x86_64" => [
        { name: "owner-id", values: %w{099720109477} },
        { name: "name", values: %w{ubuntu/images/*/ubuntu-*-14*} },
        { name: "architecture", values: %w(x86_64) },
      ],

      "windows" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-*-RTM*-English-*-Base-*} },
      ],
      "windows-2008" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2008-RTM*-English-*-Base-*} },
      ],
      "windows-2012" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2012-RTM*-English-*-Base-*} },
      ],
      "windows-2012r2" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2012-R2*-English-*-Base-*} },
      ],
      "windows-x86_64" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-*-RTM*-English-*-Base-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
      "windows-2012r2-x86_64" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2012-R2*-English-*-Base-*} },
        { name: "architecture", values: %w(x86_64) },
      ],

      "windows-server" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-*-RTM*-English-*-Base-*} },
      ],
      "windows-server-2008" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2008-RTM*-English-*-Base-*} },
      ],
      "windows-server-2012" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2012-RTM*-English-*-Base-*} },
      ],
      "windows-server-2012r2" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2012-R2*-English-*-Base-*} },
      ],
      "windows-server-x86_64" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-*-RTM*-English-*-Base-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
      "windows-server-2012r2-x86_64" => [
        { name: "owner-alias", values: %w{amazon} },
        { name: "name", values: %w{Windows_Server-2012-R2*-English-*-Base-*} },
        { name: "architecture", values: %w(x86_64) },
      ],
    }

    let(:driver) { Kitchen::Driver::Ec2.new(region: "us-west-2", aws_ssh_key_id: "foo", **config) }
    let(:config) { {} }
    let(:image) { FakeImage.new }
    def new_instance(platform_name: "blarghle")
      Kitchen::Instance.new(
        driver: driver,
        suite: Kitchen::Suite.new(name: "suite-name"),
        platform: Kitchen::Platform.new(name: platform_name),
        provisioner: Kitchen::Provisioner::Dummy.new,
        transport: Kitchen::Transport::Dummy.new,
        verifier: Kitchen::Verifier::Dummy.new,
        state_file: Kitchen::StateFile.new("/nonexistent", "suite-name-#{platform_name}")
      )
    end

    PLATFORM_SEARCHES.each do |platform_name, filters|
      context "when platform is #{platform_name}" do

        it "searches for #{filters} and uses the resulting image" do
          expect(driver.ec2.resource).to receive(:images).with(filters: filters).and_return([ image ])
          expect(driver.ec2.resource).to receive(:image).with(image.id).and_return(image)

          new_instance(platform_name: platform_name)

          expect(driver.send(:config)[:image_id]).to eq(image.id)
        end
      end
    end

    context "when image_search is provided" do
      let(:config) { { image_search: { name: "SuperImage" } } }

      context "and platform.name is a well known platform name" do
        it "searches for an image id without using the standard filters" do
          expect(driver.ec2.resource).to receive(:images).with(filters: [ { name: "name", values: %w{SuperImage} }]).and_return([ image ])
          expect(driver.ec2.resource).to receive(:image).with(image.id).and_return(image)

          new_instance(platform_name: "ubuntu")

          expect(driver.send(:config)[:image_id]).to eq(image.id)
        end
      end

      context "and platform.name is not a well known platform name" do
        it "searches for an image id without using the standard filters" do
          expect(driver.ec2.resource).to receive(:images).with(filters: [ { name: "name", values: %w{SuperImage} }]).and_return([ image ])
          expect(driver.ec2.resource).to receive(:image).with(image.id).and_return(image)

          new_instance(platform_name: "blarghle")

          expect(driver.send(:config)[:image_id]).to eq(image.id)
        end
      end
    end
  end
end
