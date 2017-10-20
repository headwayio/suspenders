require 'faker'
require 'factory_girl_rails'

# ensure Spring has the latest version of the factories
FactoryGirl.reload

# Allow factories to be created with just create(:user) instead of
# FactoryGirl.create(:user)
World(FactoryGirl::Syntax::Methods)
