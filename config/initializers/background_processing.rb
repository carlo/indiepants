if Rails.env.production?
  Background.mode = :threads
else
  Background.mode = :inline
end
