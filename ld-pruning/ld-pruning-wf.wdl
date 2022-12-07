version 1.0

# THIS IS A TEMPORARY COMMIT TO TEST SOMETHING ON TERRA

import "https://raw.githubusercontent.com/aofarrel/Stuart-WDL/segment_scatter/segfault.wdl"

workflow Segment_Scatter {
	input {
		# if you input 10 files and n_segments = 5, each segment gets 2 files
		Array[File] input_files
		Int n_segments
	}

	call segfault.segfault {
		input:
			inputs = input_files,
			n_segments = n_segments
	}

	scatter(segment in segfault.segments) {
		call echo_files {
			input:
				files_to_echo = segment
		}
	}
}

task echo_files {
	input {
		Array[File] files_to_echo
	}

	command <<<
	python3 << CODE
	files = ["~{sep='","' files_to_echo}"]
	for file in files:
		print(file)
	CODE
	>>>

	runtime {
		docker: "ashedpotatoes/sranwrp:1.1.0"
		memory: "4 GB"
	}
}
