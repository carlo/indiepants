FactoryGirl.define do
  factory :pants_post, :class => 'Pants::Post', parent: :document do
    body { Faker::Lorem.paragraphs(rand(1..3)).join("\n\n") }
  end
end
