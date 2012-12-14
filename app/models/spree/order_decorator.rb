Spree::Order.class_eval do

  attr_accessible :gift_code
  attr_accessor :gift_code

  # If variant is a gift card we say order doesn't already contain it so that each gift card is it's own line item.
  def contains?(variant)
    return false if variant.product.is_gift_card?
    line_items.detect { |line_item| line_item.variant_id == variant.id }
  end

  # Finalizes an in progress order after checkout is complete.
  # Called after transition to complete state when payments will have been processed.
  def finalize_with_gift_card!
    finalize_without_gift_card!
    # Send out emails for any newly purchased gift cards.
    self.line_items.each do |li|
      Spree::OrderMailer.gift_card_email(li.gift_card, self).deliver if li.gift_card
    end
    # Record any gift card redemptions.
    self.adjustments.where(originator_type: 'Spree::GiftCard').each do |adjustment|
      adjustment.originator.debit(adjustment.amount, self)
    end
  end
  alias_method_chain :finalize!, :gift_card

  # Tells us if there is the specified gift code already associated with the order
  # regardless of whether or not its currently eligible.
  def gift_credit_exists?(gift_card)
    !! adjustments.gift_card.reload.detect { |credit| credit.originator_id == gift_card.id }
  end

  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine :initial => 'cart', :use_transactions => false do

      event :next do
        transition :from => 'cart',     :to => 'address'
        transition :from => 'address',  :to => 'delivery'
        transition :from => 'delivery', :to => 'payment', :if => :payment_required?
        transition :from => 'payment', :to => 'complete'
        transition :from => 'confirm',  :to => 'complete'

        # note: some payment methods will not support a confirm step
        transition :from => 'payment',  :to => 'confirm',
                                        :if => Proc.new { |order| order.payment_method && order.payment_method.payment_profiles_supported? }

        transition :from => 'payment', :to => 'complete'
      end

      event :cancel do
        transition :to => 'canceled', :if => :allow_cancel?
      end
      event :return do
        transition :to => 'returned', :from => 'awaiting_return', :unless=>:awaiting_returns?
      end
      event :resume do
        transition :to => 'resumed', :from => 'canceled', :if => :allow_resume?
      end
      event :authorize_return do
        transition :to => 'awaiting_return'
      end

      before_transition :to => 'complete' do |order|
        begin
          order.process_payments!
        rescue Core::GatewayError
          !!Spree::Config[:allow_checkout_on_gateway_error]
        end
      end

      before_transition :to => ['delivery'] do |order|
        order.shipments.each { |s| s.destroy unless s.shipping_method.available_to_order?(order) }
      end

      after_transition :to => 'complete', :do => :finalize!
      after_transition :to => 'delivery', :do => :create_tax_charge!
      before_transition :to => 'delivery',  :do => :set_default_shipping_method
      after_transition :to => 'resumed',  :do => :after_resume
      after_transition :to => 'canceled', :do => :after_cancel
    end

    def check_gift_card
      line_items.each do |line_item|
       if !(line_item.gift_card)
            return true
       end
      end
           return false
    end

    def set_default_shipping_method
           if :check_gift_card?
          self.update_attribute(:shipping_method_id, available_shipping_methods(:front_end).first.id)
          self.create_shipment!
          self.update!
          reload
          end
     end


 
end
