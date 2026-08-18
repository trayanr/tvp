# inject, not sum: Enumerable#sum arrived in 2.4 and this suite runs on 2.0.
squares = (1..10).map { |n| n * n }
print squares.select(&:even?).inject(:+)
