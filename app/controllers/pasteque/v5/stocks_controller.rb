class Pasteque::V5::StocksController < Pasteque::V5::BaseController
  manage_restfully only: [:index], model: :product
end
