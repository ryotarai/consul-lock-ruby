require "spec_helper"

require "open3"

describe Consul::Lock::Semaphore do
  around(:all) do |block|
    cmd = ["consul", "agent", "-server", "-bootstrap", "-data-dir", File.expand_path("tmp/consul")]
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      lines = []
      elected = false
      stdout.each_line do |l|
        lines << l.chomp
        if l.include?("New leader elected") || l.include?("address already in use")
          elected = true
          break
        end
      end

      unless elected
        raise "failed to launch consul server\n#{lines.join("\n")}"
      end
      block.call
    end
  end

  before do
    described_class.new("spec", 2).reset
  end

  describe "#with_lock" do
    it "locks" do
      result = []
      threads = 3.times.map do |i|
        sleep 0.1
        Thread.start do
          s = described_class.new("spec", 2)
          s.with_lock do
            result << "start#{i + 1}"
            sleep 1
            result << "end#{i + 1}"
          end
        end.tap do |th|
          th.abort_on_exception = true
        end
      end

      threads.each(&:join)

      expect(result).to eq(%w!start1 start2 end1 start3 end2 end3!)
    end
  end
end
