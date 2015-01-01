def fix_up_currency(x)
  if x[0] == '$'
    x[1..-1].to_d
  else
    x[2..-2].to_d * -1
  end
end

def fix_up_date(x)
  if x.present?
    if x =~ / /
      d, ti = x.split(' ')
    else
      d = x
    end

    m, d, y = d.split('/').map{|i| if i.length == 1 then "0#{i}" else i end}
    #puts m, d, y
    if ti.nil? || ti == '0:00:00'
      "#{y}-#{m}-#{d}"
    else
      "#{y}-#{m}-#{d} #{ti}"
    end
  else
    x
  end
end
