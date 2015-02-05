namespace :docker do
  desc "Build Docker image using current code"
  task :build do
    sh 'docker build -t hmans/indiepants .'
  end
end
