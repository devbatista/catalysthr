namespace :cbo do
  desc "Load the official CBO occupations from db/data/cbo2002_ocupacao.csv (db/data/README.md)"
  task import: :environment do
    puts "#{CboOccupation.import!} ocupações carregadas."
  end
end
