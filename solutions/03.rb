require 'bigdecimal'
require 'bigdecimal/util'

class CouponAmount
  attr_reader :name

  def initialize(name, amount)
    @name = name
    @amount = amount
  end

  def coupon_discount(total)
    @amount > total ? total : @amount
  end

  def invoice_info(total)
    info = sprintf("Coupon #{ @name } - %.2f off", @amount)
    sprintf("| %-47s| %8.2f |\n", info, -coupon_discount(total))
  end
end

class CouponPercent
  attr_reader :name

  def initialize(name, amount)
    @name = name
    @amount = amount
  end

  def coupon_discount(total)
    total * (@amount / '100'.to_d)
  end

  def invoice_info(total)
    info = "Coupon #{ @name } - #{ @amount }% off"
    sprintf("| %-47s| %8.2f |\n", info, -coupon_discount(total))
  end
end

class PromotionGetOneFree
  def initialize(needed)
    @needed = needed
  end

  def discount(price, count)
    (count / @needed) * price
  end

  def invoice_info(price, count)
    discount = discount(price, count)
    if discount > 0
      info = "(buy #{ @needed - 1 }, get 1 free)"
      sprintf("|   %-45s| %8.2f |\n", info, -discount)
    else
      ""
    end
  end
end

class PromotionPackage
  def initialize(needed, percent)
    @needed = needed
    @percent = percent
  end

  def discount(price, count)
    ((count - count % @needed) * price) * (@percent / '100'.to_d)
  end

  def invoice_info(price, count)
    discount = discount(price, count)
    if discount > 0
      info = "(get #{ @percent }% off for every #{ @needed })"
      sprintf("|   %-45s| %8.2f |\n", info, -discount)
    else
      ""
    end
  end
end

class PromotionThreshold
  def initialize(needed, percent)
    @needed = needed
    @percent = percent
  end

  def discount(price, count)
    if count > @needed
      ((count - @needed) * price) * (@percent / '100'.to_d)
    else
      "0".to_d
    end
  end

  def invoice_info(price, count)
    discount = discount(price, count)
    if discount > 0
      info = "(#{ @percent }% off of every after the #{ @needed }"
      info += number_suffix(@needed % 10) + ")"
      sprintf("|   %-45s| %8.2f |\n", info, -discount)
    else
      ""
    end
  end

  def number_suffix(digit)
    if digit == 1
      "st"
    elsif digit == 2
      "nd"
    elsif digit == 3
      "rd"
    else
      "th"
    end
  end
end

class Product
  attr_reader :name

  def initialize(name, price, prom)
    @name = name
    @price = price
    @prom = parse_promotion(prom) if prom
  end

  def parse_promotion(prom)
    args = prom.flatten
    if args[0] == :get_one_free
      PromotionGetOneFree.new(args[1])
    elsif args[0] == :package
      PromotionPackage.new(*args[1].flatten)
    else
      PromotionThreshold.new(*args[1].flatten)
    end
  end

  def multi_price(product_count)
    @price * product_count
  end

  def discount(product_count)
    @prom ? @prom.discount(@price, product_count) : "0".to_d
  end

  def invoice_info(product_count)
    multi = multi_price(product_count)
    info = sprintf("| %-43s%3s | %8.2f |\n", @name, product_count.to_s, multi)
    @prom ? info + @prom.invoice_info(@price, product_count) : info
  end
end

class Inventory
  attr_reader :products, :coupons

  def initialize
    @products = []
    @coupons = []
  end

  def find_product(product_name)
    product = @products.detect { |product| product.name == product_name }
    if not product
      raise "Invalid product - #{ product_name }."
    else
      product
    end
  end

  def find_coupon(coupon_name)
    coupon = @coupons.detect { |coupon| coupon.name == coupon_name }
    if not coupon
      raise "Invalid coupon - #{ coupon_name }."
    else
      coupon
    end
  end

  def register(product_name, price_string, promotion = nil)
    price = price_string.to_d
    if @products.map(&:name).include? product_name or
      product_name.length > 40 or price < 0.01 or price > 999.99
      raise "Invalid product name/price - #{ product_name }/#{ price_string }."
    end
    @products << Product.new(product_name, price, promotion)
  end

  def register_coupon(name, kind)
    if @coupons.map(&:name).include? name
      raise "Existing coupon - #{ name }."
    end
    kind = kind.flatten
    if kind[0] == :amount
      @coupons << CouponAmount.new(name, kind[1].to_d)
    else
      @coupons << CouponPercent.new(name, kind[1])
    end
  end

  def new_cart
    Cart.new(self)
  end
end

class Cart
  def initialize(inventory)
    @inventory = inventory
    @purchased = Hash.new(0)
  end

  def add(product_name, qty = 1)
    @inventory.find_product(product_name)
    if @purchased[product_name] + qty < 1 or @purchased[product_name] + qty > 99
      raise "Invalid product count - #{ product_name } - "
        + (@purchased[product_name] + qty).to_s + "."
    end
    @purchased[product_name] += qty
  end

  def total_no_coupon
    no_coupon = "0".to_d
    @purchased.each do |product_name, qty|
      product = @inventory.find_product(product_name)
      multi_price = product.multi_price(qty)
      discount = product.discount(qty)
      no_coupon += multi_price - discount
    end
    no_coupon
  end

  def total
    total_price = total_no_coupon
    total_price -= @used_coupon.coupon_discount(total_price) if @used_coupon
    total_price
  end

  def use(coupon_name)
    if @used_coupon
      raise "Already using a coupon - #{ @used_coupon.name }."
    end
    @used_coupon = @inventory.find_coupon(coupon_name)
  end

  def invoice_header
    header = "+------------------------------------------------+----------+\n"
    header += "| Name                                       qty |    price |\n"
    header + "+------------------------------------------------+----------+\n"
  end

  def invoice_footer(final_price)
    footer = "+------------------------------------------------+----------+\n"
    footer += sprintf("| %-47s| %8.2f |\n", "TOTAL", final_price)
    footer + "+------------------------------------------------+----------+\n"
  end

  def invoice
    invoice = invoice_header
    @purchased.each do |product_name, qty|
      invoice += @inventory.find_product(product_name).invoice_info(qty)
    end
    final_price = total_no_coupon
    invoice += @used_coupon.invoice_info final_price if @used_coupon
    final_price -= @used_coupon.coupon_discount final_price if @used_coupon
    invoice + invoice_footer(final_price)
  end
end
