require "pty"

module Exports
  # The ZIP with AES-256 by the 7-Zip in the container (D-514, RN-20-013). The password never
  # goes on the command line nor in the logs (P-20-07): 7-Zip does not read it from the
  # environment, so `-p` without a value makes it ask, and the password is typed through a
  # pseudo-terminal. Above the part's size, the ZIP leaves in volumes .zip.001, .zip.002...
  # (D-667); a single volume is renamed back to .zip. A 7-Zip that stops answering is killed
  # after the time limit, so it never holds the `imports` queue.
  module SevenZip
    class Failed < StandardError; end

    PROMPT = /password[^\n]*:\s*\z/i
    TIME_LIMIT = 4.hours

    module_function

    # Returns the paths of the parts, in order.
    def encrypt!(dir:, entries:, zip_path:, password:, volume_size:, time_limit: TIME_LIMIT)
      args = [ "7z", "a", "-tzip", "-mem=AES256", "-mx=5", "-bd", "-y", "-v#{volume_size}b", "-p", zip_path, *entries ]
      run(args, dir, password, time_limit)

      parts = Dir.glob("#{zip_path}.[0-9][0-9][0-9]").sort
      raise Failed, "7z wrote no part" if parts.empty?
      return parts unless parts.one?

      File.rename(parts.first, zip_path)
      [ zip_path ]
    end

    def run(args, dir, password, time_limit)
      output = +""
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + time_limit
      status = nil
      PTY.spawn(*args, chdir: dir) do |reader, writer, pid|
        buffer = +""
        begin
          loop do
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            unless remaining.positive? && reader.wait_readable(remaining)
              Process.kill("KILL", pid)
              Process.wait(pid)
              raise Failed, "7z stopped answering after #{time_limit.to_i} seconds"
            end

            chunk = reader.readpartial(4096)
            buffer << chunk
            if buffer.match?(PROMPT)
              writer.write("#{password}\n")
              buffer = +""
            else
              output << chunk
            end
          end
        rescue Errno::EIO, EOFError
          # The command ended.
        end
        _pid, status = Process.wait2(pid)
      end
      # The password is typed with the echo off, but the output is cleaned anyway before going
      # to the error.
      raise Failed, "7z exited with #{status&.exitstatus}: #{output.gsub(password, "[FILTERED]").strip.last(300)}" unless status&.success?
    end
  end
end
