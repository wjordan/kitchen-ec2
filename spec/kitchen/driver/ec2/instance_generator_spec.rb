# -*- encoding: utf-8 -*-
#
# Author:: Tyler Ball (<tball@chef.io>)
#
# Copyright (C) 2015, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "kitchen/driver/aws/instance_generator"
require "kitchen/driver/aws/client"
require "tempfile"
require "base64"

describe Kitchen::Driver::Aws::InstanceGenerator do

  let(:config) { Hash.new }
  let(:resource) { instance_double(Aws::EC2::Resource) }
  let(:ec2) { instance_double(Kitchen::Driver::Aws::Client, :resource => resource) }
  let(:logger)        { instance_double(Logger) }
  let(:generator) { Kitchen::Driver::Aws::InstanceGenerator.new(config, ec2, logger) }

  describe "#debug_if_root_device" do
    let(:image_id) { "ami-123456" }
    let(:config) { { :image_id => image_id } }
    let(:image) { double("image") }

    before do
      allow(resource).to receive(:image).with(image_id).and_return(image)
    end

    it "returns nil when provided nil" do
      expect(generator.debug_if_root_device(nil)).to eq(nil)
    end

    it "returns nil when provided empty" do
      expect(generator.debug_if_root_device([])).to eq(nil)
    end

    it "returns nil when the image cannot be found" do
      expect(image).to receive(:root_device_name).and_raise(
        ::Aws::EC2::Errors::InvalidAMIIDNotFound.new({}, "")
      )
      expect(logger).to_not receive(:info)
      expect(generator.debug_if_root_device([{ :device_name => "name" }])).to eq(nil)
    end

    it "logs an info message when the device mappings are overriding the root device" do
      expect(image).to receive(:root_device_name).and_return("name")
      expect(logger).to receive(:info)
      expect(generator.debug_if_root_device([{ :device_name => "name" }])).to eq(nil)
    end
  end

  describe "#prepared_user_data" do
    context "when config[:user_data] is a file" do
      let(:tmp_file) { Tempfile.new("prepared_user_data_test") }
      let(:config) { { :user_data => tmp_file.path } }

      before do
        tmp_file.write("foo\nbar")
        tmp_file.rewind
      end

      after do
        tmp_file.close
        tmp_file.unlink
      end

      it "reads the file contents" do
        expect(Base64.decode64(generator.prepared_user_data)).to eq("foo\nbar")
      end

      it "memoizes the file contents" do
        decoded = Base64.decode64(generator.prepared_user_data)
        expect(decoded).to eq("foo\nbar")
        tmp_file.write("other\nvalue")
        tmp_file.rewind
        expect(decoded).to eq("foo\nbar")
      end
    end
  end

  describe "block_device_mappings" do
    before do
      expect(generator).to receive(:debug_if_root_device)
    end

    it "returns empty if nothing is provided" do
      expect(generator.block_device_mappings).to eq([])
    end

    context "when populated with multiple mappings" do
      let(:config) do
        { :block_device_mappings => [
          {
            :ebs_volume_size => 13,
            :ebs_delete_on_termination => true,
            :ebs_device_name => "/dev/sda1"
          },
          {
            :ebs_volume_size => 15,
            :ebs_delete_on_termination => false,
            :ebs_device_name => "/dev/sda2",
            :ebs_volume_type => "gp2",
            :ebs_snapshot_id => "id",
            :ebs_virtual_name => "test"
          },
          {
            :ebs_volume_size => 100,
            :ebs_delete_on_termination => true,
            :ebs_device_name => "/dev/sda3",
            :ebs_volume_type => "io1",
            :ebs_iops => 100
          }
        ] }
      end

      it "returns the transformed mappings" do
        expect(generator.block_device_mappings).to match(
          [
            {
              :ebs => {
                :volume_size => 13,
                :delete_on_termination => true
              },
              :device_name => "/dev/sda1"
            },
            {
              :ebs => {
                :volume_size => 15,
                :volume_type => "gp2",
                :snapshot_id => "id",
                :delete_on_termination => false
              },
              :device_name => "/dev/sda2",
              :virtual_name => "test"
            },
            {
              :ebs => {
                :volume_size => 100,
                :volume_type => "io1",
                :iops => 100,
                :delete_on_termination => true
              },
              :device_name => "/dev/sda3"
            }
          ]
        )
      end

    end

    context "when populatd with deprecated configs" do
      let(:config) do
        {
          :ebs_volume_size => 13,
          :ebs_delete_on_termination => true,
          :ebs_device_name => "/dev/sda1",
          :ebs_volume_type => "gp2"
        }
      end

      it "returns the transformed mappings" do
        expect(generator.block_device_mappings).to match(
          [
            {
              :ebs => {
                :volume_size => 13,
                :delete_on_termination => true,
                :volume_type => "gp2"
              },
              :device_name => "/dev/sda1"
            }
          ]
        )
      end
    end

    context "when populated with deprecated configs and new configs" do
      let(:config) do
        {
          :ebs_volume_size => 13,
          :ebs_delete_on_termination => true,
          :ebs_device_name => "/dev/sda1",
          :ebs_volume_type => "gp2",
          :block_device_mappings => [
            {
              :ebs_volume_size => 15,
              :ebs_delete_on_termination => false,
              :ebs_device_name => "/dev/sda2",
              :ebs_volume_type => "gp2",
              :ebs_snapshot_id => "id",
              :ebs_virtual_name => "test"
            }
          ]
        }
      end

      it "ignores the old configs" do
        expect(generator.block_device_mappings).to match(
          [
            {
              :ebs => {
                :volume_size => 15,
                :volume_type => "gp2",
                :snapshot_id => "id",
                :delete_on_termination => false
              },
              :device_name => "/dev/sda2",
              :virtual_name => "test"
            }
          ]
        )
      end
    end
  end

  describe "#ec2_instance_data" do
    before do
      expect(generator).to receive(:debug_if_root_device)
    end

    it "returns empty on nil" do
      expect(generator.ec2_instance_data).to eq(
        :instance_type => nil,
        :ebs_optimized => nil,
        :image_id => nil,
        :key_name => nil,
        :subnet_id => nil,
        :private_ip_address => nil
      )
    end

    context "when populated with minimum requirements" do
      let(:config) do
        {
          :availability_zone            => "eu-west-1a",
          :instance_type                => "micro",
          :ebs_optimized                => true,
          :image_id                     => "ami-123",
          :aws_ssh_key_id               => "key",
          :subnet_id                    => "s-456",
          :private_ip_address           => "0.0.0.0"
        }
      end

      it "returns the minimum data" do
        expect(generator.ec2_instance_data).to eq(
          :instance_type => "micro",
          :ebs_optimized => true,
          :image_id => "ami-123",
          :key_name => "key",
          :subnet_id => "s-456",
          :private_ip_address => "0.0.0.0"
        )
      end
    end

    context "when subnet_id is provided" do
      let(:config) do
        {
          :subnet_id => "s-456"
        }
      end

      it "adds a network_interfaces block" do
        expect(generator.ec2_instance_data).to eq(
          :instance_type => nil,
          :ebs_optimized => nil,
          :image_id => nil,
          :key_name => nil,
          :subnet_id => "s-456",
          :private_ip_address => nil
        )
      end
    end

    context "when associate_public_ip is provided" do
      let(:config) do
        {
          :associate_public_ip => true
        }
      end

      it "adds a network_interfaces block" do
        expect(generator.ec2_instance_data).to eq(
          :instance_type => nil,
          :ebs_optimized => nil,
          :image_id => nil,
          :key_name => nil,
          :subnet_id => nil,
          :private_ip_address => nil,
          :network_interfaces => [{
            :device_index => 0,
            :associate_public_ip_address => true,
            :delete_on_termination => true
          }]
        )
      end

      context "and subnet is provided" do
        let(:config) do
          {
            :associate_public_ip => true,
            :subnet_id => "s-456"
          }
        end

        it "adds a network_interfaces block" do
          expect(generator.ec2_instance_data).to eq(
            :instance_type => nil,
            :ebs_optimized => nil,
            :image_id => nil,
            :key_name => nil,
            :private_ip_address => nil,
            :network_interfaces => [{
              :device_index => 0,
              :associate_public_ip_address => true,
              :delete_on_termination => true,
              :subnet_id => "s-456"
            }]
          )
        end
      end

      context "and security_group_ids is provided" do
        let(:config) do
          {
            :associate_public_ip => true,
            :security_group_ids => ["sg-789"]
          }
        end

        it "adds a network_interfaces block" do
          expect(generator.ec2_instance_data).to eq(
            :instance_type => nil,
            :ebs_optimized => nil,
            :image_id => nil,
            :key_name => nil,
            :subnet_id => nil,
            :private_ip_address => nil,
            :network_interfaces => [{
              :device_index => 0,
              :associate_public_ip_address => true,
              :delete_on_termination => true,
              :groups => ["sg-789"]
            }]
          )
        end

        it "accepts a single string value" do
          config[:security_group_ids] = "only-one"

          expect(generator.ec2_instance_data).to include(
            :network_interfaces => [{
              :device_index => 0,
              :associate_public_ip_address => true,
              :delete_on_termination => true,
              :groups => ["only-one"]
            }]
          )
        end
      end

      context "and private_ip_address is provided" do
        let(:config) do
          {
            :associate_public_ip => true,
            :private_ip_address => "0.0.0.0"
          }
        end

        it "adds a network_interfaces block" do
          expect(generator.ec2_instance_data).to eq(
            :instance_type => nil,
            :ebs_optimized => nil,
            :image_id => nil,
            :key_name => nil,
            :subnet_id => nil,
            :network_interfaces => [{
              :device_index => 0,
              :associate_public_ip_address => true,
              :delete_on_termination => true,
              :private_ip_address => "0.0.0.0"
            }]
          )
        end
      end
    end

    context "when provided the maximum config" do
      let(:config) do
        {
          :availability_zone            => "eu-west-1a",
          :instance_type                => "micro",
          :ebs_optimized                => true,
          :image_id                     => "ami-123",
          :aws_ssh_key_id               => "key",
          :subnet_id                    => "s-456",
          :private_ip_address           => "0.0.0.0",
          :block_device_mappings => [
            {
              :ebs_volume_size => 15,
              :ebs_delete_on_termination => false,
              :ebs_device_name => "/dev/sda2",
              :ebs_volume_type => "gp2",
              :ebs_snapshot_id => "id",
              :ebs_virtual_name => "test"
            }
          ],
          :security_group_ids => ["sg-789"],
          :user_data => "foo",
          :iam_profile_name => "iam-123",
          :associate_public_ip => true
        }
      end

      it "returns the maximum data" do
        expect(generator.ec2_instance_data).to eq(
          :instance_type => "micro",
          :ebs_optimized => true,
          :image_id => "ami-123",
          :key_name => "key",
          :block_device_mappings => [
            {
              :ebs => {
                :volume_size => 15,
                :delete_on_termination => false,
                :volume_type => "gp2",
                :snapshot_id => "id"
              },
              :device_name => "/dev/sda2",
              :virtual_name => "test"
            }
          ],
          :iam_instance_profile => { :name => "iam-123" },
          :network_interfaces => [{
            :device_index => 0,
            :associate_public_ip_address => true,
            :subnet_id => "s-456",
            :delete_on_termination => true,
            :groups => ["sg-789"],
            :private_ip_address =>  "0.0.0.0"
          }],
          :user_data => Base64.encode64("foo")
        )
      end
    end
  end
end
