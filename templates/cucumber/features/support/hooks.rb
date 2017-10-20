AfterStep('@pause') do
  print "Press Return to continue ..."
  STDIN.getc
end

AfterStep('@pry') do
  require 'pry'; binding.pry
end
