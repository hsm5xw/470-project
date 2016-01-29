#!/bin/bash

current_dir=$(pwd)

correct_outputs_dir_name="correct_outputs"
correct_outputs_dir=$current_dir
correct_outputs_dir+="/"
correct_outputs_dir+=$correct_outputs_dir_name

testing_dir_name="testing_outputs"
testing_outputs_dir=$current_dir
testing_outputs_dir+="/"
testing_outputs_dir+=$testing_dir_name

num_writeback_mismatch=0
num_program_mismatch=0

for file in test_progs/*.s; do

	filename=$(echo $file | cut -d'.' -f1 | cut -d'/' -f2)

	correct_outputs_sub_dir=$correct_outputs_dir
	correct_outputs_sub_dir+="/"
	correct_outputs_sub_dir+=$filename

	testing_outputs_sub_dir=$testing_outputs_dir
	testing_outputs_sub_dir+="/"
	testing_outputs_sub_dir+=$filename

	correct_outputs_writeback=$correct_outputs_sub_dir
	correct_outputs_writeback+="/"
	correct_outputs_writeback+="writeback.out"

	testing_outputs_writeback=$testing_outputs_sub_dir
	testing_outputs_writeback+="/"
	testing_outputs_writeback+="writeback.out"

	testing_outputs_program_out=$testing_outputs_sub_dir
	testing_outputs_program_out+="/"
	testing_outputs_program_out+="program.out"

	correct_program_out=$correct_outputs_sub_dir
	correct_outputs_out+="/"
	correct_outputs_out+="program.out"

	DIFF_WRITEBACK=$(diff $correct_outputs_writeback $testing_outputs_writeback)

	DIFF_PROGRAM=$(diff $correct_program_out $testing_outputs_program_out)

	if [ "$DIFF_WRITEBACK" != "" ] 
	then
    		echo -e "\t $filename: Writebacks are different"
		num_writeback_mismatch=$(($num_writeback_mismatch + 1))
	fi

	if [ "$DIFF_PROGRAM" != "" ] 
	then
    		echo -e "\t $filename: Program.out are different"
		num_program_mismatch=$(($num_program_mismatch + 1))
	fi
done

echo "The number of mismatches in writeback: $num_writeback_mismatch"
echo "The number of mismatches in program.out: $num_program_mismatch"

if [[ ($num_writeback_mismatch == 0) && ($num_program_mismatch == 0)]]
then
	echo -e "\n@@@Passed"

else
	echo -e "\n@@@Failed" 
fi

