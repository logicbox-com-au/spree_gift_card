require 'spree/core/validators/email'

module Spree
  class GiftCard < ActiveRecord::Base

    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    attr_accessible :email, :name, :note, :variant_id, :original_value

    belongs_to :variant
    belongs_to :line_item

    has_many :transactions, class_name: 'Spree::GiftCardTransaction'

    validates :code,               presence: true, uniqueness: true
    validates :current_value,      presence: true
    validates :email, email: true, presence: true
    validates :name,               presence: true
    validates :original_value,     presence: true

    before_validation :generate_code, on: :create
    before_validation :set_calculator, on: :create
    before_validation :set_values, on: :create
    
    after_save :update_references
    
    calculated_adjustments

    def apply(order)
      # Nothing to do if the gift card is already associated with the order
      return if order.gift_credit_exists?(self)
      order.update!
      create_adjustment(I18n.t(:gift_card), order, order)
      order.update!
    end

    # Calculate the amount to be used when creating an adjustment
    def compute_amount(calculable)
      self.calculator.compute(calculable, self)
    end

    def debit(amount, order)
      raise 'Cannot debit gift card by amount greater than current value.' if (self.current_value - amount.to_f.abs) < 0
      transaction = self.transactions.build
      transaction.amount = amount
      transaction.order  = order
      self.current_value = self.current_value - amount.abs
      self.save
    end

    def price
      self.line_item ? self.line_item.price * self.line_item.quantity : self.variant.price
    end

    def order_activatable?(order)
      order &&
      created_at < order.created_at &&
      !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    private

    def generate_code
      until self.code.present? && self.class.where(code: self.code).count == 0
        self.code = Digest::SHA1.hexdigest([Time.now, rand].join)
      end
    end

    def set_calculator
      self.calculator = Spree::Calculator::GiftCard.new
    end
    
    
  def set_values
        self.current_value  =self.original_value
#create new product as gift_certificate
             product=Product.new()
             product.name = "GIFT CERTIFICATE"
             product.description = "Celebrate this X'Mas with gourmetgoldmine.com.au"
             product.sku = "GIFT"
             product.is_gift_card = "t"
             product.master.price = self.original_value
             product.available_on = DateTime.now - 1.day
             product.deleted_at = DateTime.now + 365.day
             product.save!
        #get master variant_id of the new product
        self.variant_id=ActiveRecord::Base.connection.execute 'select  id from spree_variants WHERE sku=\'GIFT\' ORDER BY id DESC LIMIT 1'
      end
      
      def update_references
#update the count of new product
        ActiveRecord::Base.connection.execute 'UPDATE spree_products SET count_on_hand=1 WHERE "id"=(SELECT "id" FROM spree_products WHERE "name"=\'GIFT CERTIFICATE\' ORDER BY "id" DESC LIMIT 1)'
     #update line_items with new product_id and variant_id   
ActiveRecord::Base.connection.execute 'UPDATE spree_line_items SET variant_id=(select  id from spree_variants WHERE sku= \'GIFT\' ORDER BY id DESC LIMIT 1) WHERE "id"=(select  id from spree_line_items WHERE variant_id=1 ORDER BY id DESC LIMIT 1)'
   #update gift_cards with new products ids   
     ActiveRecord::Base.connection.execute 'UPDATE spree_gift_cards SET variant_id = ( SELECT "id" FROM spree_variants WHERE sku= \'GIFT\' ORDER BY "id" DESC LIMIT 1 ), line_item_id = ( SELECT "id" FROM spree_line_items ORDER BY "id" DESC LIMIT 1 ) WHERE "id" = ( SELECT "id" FROM spree_gift_cards ORDER BY "id" DESC LIMIT 1 )'
      end
      

  end
end
