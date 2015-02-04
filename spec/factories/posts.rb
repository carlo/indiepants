FactoryGirl.define do
  factory :post do
    type 'pants.post'
    user
    body "Lorem Ipsum."
  end
end
