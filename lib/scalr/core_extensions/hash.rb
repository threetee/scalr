class Hash
  
  def downcase_keys
    inject({}) do |options, (key, value)|
      options[(key.downcase.to_sym rescue key) || key] = value
      options
    end
  end
  
  def downcase_keys!
    self.replace(self.downcase_keys)
  end
  
  def recursive_downcase_keys!
    downcase_keys!
    values.each{|h| h.recursive_downcase_keys! if h.is_a?(Hash) }
    values.select{|v| v.is_a?(Array) }.flatten.each{|h| h.recursive_downcase_keys! if h.is_a?(Hash) }
    self
  end
  
end