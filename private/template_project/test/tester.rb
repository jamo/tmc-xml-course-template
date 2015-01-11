require 'yaml'
require 'set'
require 'open3'
require 'json'


def recursive_symbolize_keys(h)
  case h
  when Hash
    Hash[
      h.map do |k, v|
        [ k.respond_to?(:to_sym) ? k.to_sym : k, recursive_symbolize_keys(v) ]
      end
    ]
  when Enumerable
    h.map { |v| recursive_symbolize_keys(v) }
  else
    h
  end
end


options = YAML.load_file 'xml-test-spec.yml'
options = recursive_symbolize_keys(options)

if ARGV[0] == "--print-available-points"
  points = Set.new
  options[:testcases][:tests].each do |testcase|
    points << testcase[:points].uniq.sort
  end
  $stdout.puts points.flatten.sort.join("\n")
  exit 0
end

def format_command(testcase)
  testcase[:command].join(" ")
end

def run_commamd_printing_command(command, hash)
  Dir.chdir("../") do
    $stdout.puts command % hash
    Open3.capture3({"PATH" => ".:#{ENV["PATH"]}"}, (command % hash))
  end
end

# Lets ignore paths for solution and for submission source
def process_diff(str, solution_hash, student_hash)
  common_keys = solution_hash.keys & student_hash.keys
  common_keys.each do |key|
    str.gsub!(solution_hash[key], student_hash[key])
  end
  str.gsub!('test/', '')
  str.gsub!('src/', '')

  str.strip!
  str
end


def diff(solution, student, solution_hash, student_hash)
  solution = process_diff(solution, solution_hash, student_hash)
  student = process_diff(student, solution_hash, student_hash)
  solution==student
end

def wrap(str, out)
  out.puts "↓"*80
  out.puts str
  out.puts "↑"*80
  out.puts
end


# Lets go thru all testcases, run command defined for model solution and for students code.
results = []
options[:testcases][:tests].each do |testcase|
  testcase_results = {}
  puts "Testcase #{testcase[:description]}"
  puts "Points related: #{testcase[:points].uniq.sort.join(", ")}"
  puts
  # MODEL SOLUTION
  solution_hash = testcase[:solution_run]
  student_hash = testcase[:student_run]
  stdout_solution, stderr_solution, status_solution = run_commamd_printing_command(format_command(testcase),  solution_hash)
  # STUDENTS SOLUTION
  stdout_student, stderr_student, status_student = run_commamd_printing_command(format_command(testcase),  student_hash)

  # Printing stuff, not sure if relevant
  $stdout.puts "solution"
  wrap(process_diff(stdout_solution, solution_hash, student_hash), $stdout)
  $stdout.puts "student"
  wrap(process_diff(stdout_student, solution_hash, student_hash), $stdout)
  $stdout.puts "result: "
  # Store diff result for stdout
  stdout_res = diff(stdout_solution, stdout_student, solution_hash, student_hash)
  wrap(stdout_res,  $stdout)


  $stderr.puts "solution"
  wrap(process_diff(stderr_solution, solution_hash, student_hash), $stderr)
  $stderr.puts "student"
  wrap(process_diff(stderr_student, solution_hash, student_hash), $stderr)
  $stderr.puts "result: "
  # Store diff result for stderr
  stderr_res = diff(stderr_solution, stderr_student, solution_hash, student_hash)
  wrap(stderr_res, $stderr)

  # Generate test case result
  testcase_results['methodName'] = testcase[:description]
  testcase_results['pointNames'] = testcase[:points].uniq.sort
  testcase_results['status'] = (stdout_res && stderr_res) ? 'PASSED' : 'FAILED'
  testcase_results['message'] = "STDOUT: #{stdout_res}\n"
  testcase_results['message'] << "STDERR: #{stderr_res}"
  results << testcase_results
end

# Store results
File.write('../test_output.txt', results.to_json)
