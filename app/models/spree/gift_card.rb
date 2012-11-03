require 'spree/core/validators/email'

module Spree
  class GiftCard < ActiveRecord::Base

    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    attr_accessible :email, :name, :note, :variant_id, :original_value

    belongs_to :variant
    belongs_to :line_item

       after_save :inserton

    has_many :transactions, class_name: 'Spree::GiftCardTransaction'

    validates :code,               presence: true, uniqueness: true
    validates :current_value,      presence: true
    validates :email, email: true, presence: true
    validates :name,               presence: true
    validates :original_value,     presence: true

    before_validation :generate_code, on: :create
    before_validation :set_calculator, on: :create
    before_validation :set_values, on: :create

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
    
  def inserton
         ActiveRecord::Base.connection.execute "DROP TRIGGER IF EXISTS INSERTGIFTS ON spree_gift_cards"
                 sql= <<-SQL
           CREATE OR REPLACE FUNCTION inserton()                                                                
                      RETURNS TRIGGER                                                 
                      AS                                       
                      $TRIGGER_Event_Type$
                       BEGIN   
                         insert into spree_products(name,available_on, permalink,meta_description,created_at,updated_at,count_on_hand,is_gift_card) values('GIFT CERTIFICATES',(SELECT CURRENT_TIMESTAMP),'GIFT CERTIFICATES','GIFT CERTIFICATES',(SELECT CURRENT_TIMESTAMP),(SELECT CURRENT_TIMESTAMP),1,'t');
                         insert into spree_variants(id,sku,price,product_id)values((select  id from spree_products ORDER BY id DESC LIMIT 1),'GIFTCERTIFICATES',(SELECT original_value FROM spree_gift_cards ORDER BY id DESC LIMIT 1),(select  id from spree_products ORDER BY id DESC LIMIT 1));
                         update spree_gift_cards set variant_id=(select id from spree_products where name='GIFT CERTIFICATES' LIMIT 1)where id=(SELECT id FROM spree_gift_cards ORDER BY id DESC LIMIT 1);
                         update spree_line_items set variant_id=(select id from spree_variants ORDER BY id DESC LIMIT 1) WHERE id=(select "id" FROM spree_line_items ORDER BY created_at DESC LIMIT 1);
                         UPDATE spree_gift_cards SET line_item_id = ( SELECT ID FROM spree_line_items WHERE variant_id = ( SELECT ID FROM spree_variants ORDER BY ID DESC LIMIT 1 ) ORDER BY ID DESC LIMIT 1 ) WHERE ID = ( SELECT ID FROM spree_gift_cards ORDER BY ID DESC LIMIT 1 );
                         return new;               
             END;
         $TRIGGER_Event_Type$ 
         LANGUAGE plpgsql;
         
        DROP TRIGGER IF EXISTS INSERTGIFTS ON spree_gift_cards;
        
        create trigger INSERTGIFTS BEFORE INSERT ON spree_gift_cards  
        FOR EACH ROW EXECUTE PROCEDURE inserton();
        SQL
        ActiveRecord::Base.connection.execute sql          
    end
    
  def set_values
    #self.current_value=self.variant.try(:price)
   # self.original_value =self.variant.try(:price)
        self.current_value  =self.original_value
        self.original_value = self.original_value
        self.variant_id=ActiveRecord::Base.connection.execute 'select  id from spree_variants ORDER BY id DESC LIMIT 1'
      end
  end
end
