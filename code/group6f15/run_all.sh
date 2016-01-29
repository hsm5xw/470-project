#!/bin/sh

# variables for average cpi calculation
total_cycles=$((0))
total_instrs=$((0))

current_dir=$(pwd)
dir_name="testing_outputs"
break > data.txt

testing_outputs_dir=$current_dir
testing_outputs_dir+="/"
testing_outputs_dir+=$dir_name

if [ ! -d "$testing_outputs_dir" ]; then
  mkdir $testing_outputs_dir
fi

for file in test_progs/*.s; do

	echo "Assembling $file"
	./vs-asm < $file > program.mem

	echo "Running $file"
	make > bodoh
		

	filename=$(echo $file | cut -d'.' -f1 | cut -d'/' -f2)

	sub_dir=$testing_outputs_dir
	sub_dir+="/"
	sub_dir+=$filename

	if [ ! -d "$sub_dir" ]; then
  	  mkdir $sub_dir
	fi

	cp writeback.out $sub_dir

	echo "" >> data.txt
	echo $filename >> data.txt
	grep 'CPI' bodoh | cut -d'@' -f3 >> data.txt
	grep 'Prediction' bodoh >> data.txt

	grep '@@@' bodoh > program.out

	# average cpi calculation
	cycles=$(grep 'CPI' bodoh | cut -d's' -f1 | grep -o '[0-9]*')
	instrs=$(grep 'CPI' bodoh | cut -d'e' -f2 | cut -d'i' -f1 | grep -o '[0-9]*')
	total_cycles=$((total_cycles + cycles))
	total_instrs=$((total_instrs + instrs))

	cp program.out $sub_dir

done

cpi=$(echo "$total_cycles/$total_instrs" | bc -l)
echo "" >> data.txt
echo 'average CPI: '$cpi >> data.txt

mv data.txt data_rs8.txt
