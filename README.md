SpreeGiftCard [![Build Status](https://secure.travis-ci.org/jdutil/spree_gift_card.png)](http://travis-ci.org/jdutil/spree_gift_card) [![Dependency Status](https://gemnasium.com/jdutil/spree_gift_card.png?travis)](https://gemnasium.com/jdutil/spree_gift_card)
=============

This extension adds gift card functionality to spree.  It is based off the original [spree_gift_cards](http://github.com/spree/spree_gift_cards)
extension, but differs in that it does not require a user to have an account.  Gift cards may be redeemed by
entering a unique gift card code during checkout rather than applying store credits to the customers account.

Requirements
============

* Spree Core 1.1.0 or greater.
* Ruby 1.9.2 or greater.

Installation
============

1. Add `gem 'spree_gift_card', github: 'jdutil/spree_gift_card'` to Gemfile
1. Run `bundle`
1. Run `rails g spree_gift_card:install`
1. Run `rails g spree_gift_card:seed`

Testing
=======

1. bundle exec rake test_app
1. bundle exec rspec spec

Todo
====

1. Have new gift card page mimic styling of product page
1. Improve test coverage further

Copyright (c) 2012 Jeff Dutil, released under the New BSD License
