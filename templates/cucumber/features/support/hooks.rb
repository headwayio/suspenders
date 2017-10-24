AfterStep('@pause') do
  print "Press Return to continue ..."
  STDIN.getc
end

# rubocop:disable Lint/Debugger
AfterStep('@pry') do
  require 'pry'; binding.pry
end
# rubocop:enable Lint/Debugger
