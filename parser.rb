#!/usr/bin/env ruby
#
# NOTE: This script is complementary to the run script and transforms the output of the run.
# You can still use it as a standalone script if you have the verbose report locally.
#
# Usage:
#   $ ci/semgrep/parser
#   $ ci/semgrep/parser -f infile -r $GITHUB_WORKSPACE -i semgrep.ignore -p
#
# You can also add an ignore file (eg. semgrep.ignore) for specific fingerprints such as:
# {
#   "ignored_warnings": [
#     {
#       "note": "This is a custom note 1",
#       "fingerprint": "a4efd74060e37fae96be358e760d0404fe05c27d4a5acce8581277e84301fff5"
#     },
#     {
#       "note": "This is a custom note 2",
#       "fingerprint": "a29580bf83e78a27fcbc34fcf6295bf7fa0b5a6568f6f6ce4bfb67c65cfa7fab"
#     }
#   ]
# }

require 'json'
require 'digest/sha2'
require 'set'
require 'optparse'
require 'English'

SECURITY = 'security'.freeze
ERROR = "ERROR".freeze
WARNING = "WARNING".freeze
INFO = 'INFO'.freeze

opts = {
  file: '',
  root: '',
  ignore: ''
}

parser = OptionParser.new do |o|
  o.banner = '[!] Usage: ci/semgrep/parser -f infile -r $GITHUB_WORKSPACE -i semgrep.ignore'

  o.on('-f', '--file FILENAME', 'Semgrep output file to parse.') do |v|
    opts[:file] = v
  end

  o.on('-r', '--root SCANROOT', 'Removes the root directory from the output. Useful if you use custom target or temporary folders while running.') do |v|
    opts[:root] = v
  end

  o.on('-i', '--ignore IGNOREFILE', 'Removes specific fingerprints from the final output.') do |v|
    opts[:ignore] = v
  end

  o.on('-p', '--print', 'Print a JSON report.') do |v|
    opts[:print] = v
  end

  o.on('-h', '--help', 'Display this.') do
    puts o
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption, OptionParser::InvalidArgument
  puts $ERROR_INFO.to_s
  puts parser
  exit 1
end

unless File.file?(opts[:file])
  abort '[-] Semgrep file does not exist.'
end

unless File.file?(opts[:ignore]) || opts[:ignore].to_s.strip.empty?
  abort '[-] Ignore file does not exist.'
end

file = File.read(opts[:file])
results = JSON.parse(file)

if !opts[:ignore].to_s.strip.empty?
  ignore_file = File.read(opts[:ignore])
  ignore_results = JSON.parse(ignore_file)

  ignore_fingerprints =
    ignore_results['ignored_warnings'].map { |result| result['fingerprint'] }
end

# Loop the verbose report to create a pretty/brief excluding ignored
ignored = 0
findings = Set.new
fingerprints =
  results['results'].map do |result|
    extras = result['extra']
    path = result['path'].gsub(opts[:root], '')

    next unless extras['metadata']['category'] == SECURITY

    next unless extras['severity'] != INFO

    fingerprint = extras['fingerprint']

    if !opts[:ignore].to_s.strip.empty?
      if ignore_fingerprints.include?(fingerprint)
        ignored += 1
        next
      end
    end

    findings << result['check_id']

    message = extras['message']
    check_name = result['check_id']
    confidence = extras['metadata']['confidence'] || "UNDEFINED"
    impact = extras['metadata']['impact'] || "UNDEFINED"
    start_line = result['start']['line']
    end_line = result['end']['line']
    severity = extras['severity']
    references = extras['metadata']['references']
    warn_type = extras['metadata']['owasp']
    warn_detail = extras['metadata']['cwe']
    code = extras['lines'].squeeze(' ')

    # Pack parsed values into a simplified format
    {
      fingerprint: fingerprint,
      warning_type: "#{warn_type} / #{warn_detail}",
      severity: severity,
      confidence: confidence,
      impact: impact,
      check_name: check_name,
      message: message,
      file: path,
      start_line: start_line,
      end_line: end_line,
      code: code,
      references: references
    }
end.compact

# Remove overlapping rules' findings by the following pseudo-"uniq" key
fingerprints = fingerprints.uniq { |f| f.values_at(:file, :start_line, :end_line, :code) }

# Warnings count
warnings = if fingerprints.nil? then 0 else fingerprints.size end

output = {
  warnings: warnings,
  ignored_warnings: ignored,
  findings: findings.to_a,
  fingerprints: fingerprints
}

if opts[:print]
  puts JSON.pretty_generate(output)
end
