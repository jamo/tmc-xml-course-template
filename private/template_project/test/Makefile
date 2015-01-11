all: test

test:
	# nothing to do
clean:
	rm -f tmc_available_points.txt tmc_test_output.json

run: test
	# Printing available points
	ruby tester.rb --print-available-points
	ruby tester.rb
get-points:
	ruby tester.rb --print-available-points
