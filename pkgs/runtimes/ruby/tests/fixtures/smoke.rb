squares = (1..10).map { |n| n * n }
print squares.select(&:even?).sum
