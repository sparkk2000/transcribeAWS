Rails.application.routes.draw do
  get 'home/db'
  get 'home/create'
  get 'home/change'
  # post 'cmp' => 'home#cmp' as: :cmp
  get 'home/cmp'
  root 'home#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
