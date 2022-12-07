version 1.0

task T {
	input {
		File? tsv_file_input
		# if you put foo here, you get an error
		String tsv_arg = if defined(tsv_file_input) then basename(foo) else ""
	}
	String foo = select_first([tsv_file_input, "/path/to/file.txt"])

	command <<<
		echo ~{tsv_arg}
	>>>

}

workflow W {
	input {
		File? tsv_file_input
	}

	call T {
		input:
			tsv_file_input = tsv_file_input
	}
}