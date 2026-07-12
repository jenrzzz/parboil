Rails.application.routes.draw do
  root "ideas#index"

  resources :ideas, only: [ :index, :create, :show ] do
    member do
      post :answer          # one interview turn: answer -> extract -> next question
      post :next_question   # start the interview, or resume a turn that died mid-question
      post :stuck           # step the pending question down to a smaller one (never skip)
      get  :outline         # linearized markdown, curl-able (the drafting handoff)
    end

    # Raw material dropped into the pot: pasted text or a URL.
    resources :scraps, only: [ :create, :destroy ], shallow: true
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
