module Spree
  class GiftCardsController < Spree::BaseController
    helper 'spree/admin/base'

    def new
      find_gift_card_variants
      @gift_card = GiftCard.new
    end

    def create
      @gift_card = GiftCard.new(params[:gift_card])
      if @gift_card.save
        # Create line item
        line_item = LineItem.new(quantity: 1)
        line_item.gift_card = @gift_card
        line_item.variant = @gift_card.variant
        line_item.price = @gift_card.original_value
        # Add to order
        order = current_order(true)
        order.line_items << line_item
        order.save
        # Save gift card
        @gift_card.line_item = line_item
        @gift_card.save
        redirect_to cart_path
      else
        find_gift_card_variants
        render :action => :new
      end
    end

    private

    def find_gift_card_variants
      gift_card_product_ids = Product.not_deleted.where(["is_gift_card = ?", true]).map(&:id)
      @gift_card_variants = Variant.where(["price > 0 AND product_id IN (?)", gift_card_product_ids]).order("price")
    end

  end
end
