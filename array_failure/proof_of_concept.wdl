version 1.0

# This workflow demonstrates issues involving optional output. Essentially, I need a workflow
# that can tolerate bad data by putting it into a debugging task rather than having an
# instance of a scattered task return 1 (which stops the whole pipeline).
# 
#
# use case:
# In the real workflow, generate_either_alpha_or_omega is a decontamination task that attempts
# to decontaminate and combine pairs of fastqs. If it passes, it passes decontaminated fastqs
# (alpha) to the variant caller (generate_either_beta_or_gamma). If it "fails", it still
# returns 0, but it fastqs it failed to decontaminate (omega) to fastQC (check_omega_andor_gamma).
# Now, the variant caller, which itself is called iff decontamination was successful (iff alpha
# exists), can also have issues. If it passes, its final output is a VCF (beta). If it fails, it
# returns 0 but passes the decontaminated fastqs (alpha) to fastqc.
# So, fastqc (check_omega_andor_gamma) is going to take in an array that consists of either a
# bunch of decontamination failures (omega), a bunch of variant caller failures (gamma), or both.

workflow ArrayConstructionFailure {
    input {
        Array[Array[File]] nested_input_array
        File bogus
        Boolean run_check_omega_andor_gamma = true
        Boolean never_omega_nor_gamma = false
    }

	scatter(inner_array in nested_input_array) {

		# Call a task that outputs either File? alpha or File? omega
		call generate_either_alpha_or_omega {
			input:
				array_of_files = inner_array,
				always_succeed = never_omega_nor_gamma
		}

		if(defined(generate_either_alpha_or_omega.alpha)) {
			# This region only executes if alpha exists. We can use this to coerce
			# File? into File by using a select_first() where the first element is
			# the File? we know absolutely must exist, and the second element is bogus
	    	File coerced_alpha_file=select_first([generate_either_alpha_or_omega.alpha, bogus])

	    	# Call a task that outputs either File? beta or File? gamma
			call generate_either_beta_or_gamma {
				input:
					alpha = coerced_alpha_file,
					always_succeed = never_omega_nor_gamma
			}
		}
	}

	# Now, outside the scatter, we (probably) have the following arrays:
	# Array[File?] generate_either_alpha_or_omega.alpha --> successfully passed first task, input into second task
	# Array[File?] generate_either_alpha_or_omega.omega --> failed first task, should be investigated
	# Array[File?] generate_either_beta_or_gamma.beta   --> successfully passed second task (in the real pipeline this is a final output)
	# Array[File?] generate_either_beta_or_gamma.gamma  --> failed second task, should be investigated
    
    if(run_check_omega_andor_gamma) {

        # if you move this block under the next if statement, this workflow will pass miniwdl and womtool
        # however, two out of the three if statements will cause issues at runtime (unless never_omega_nor_gamma = true) 
        Array[File] coerced_omega_array_ = select_all(generate_either_alpha_or_omega.omega)
        Array[File] coerced_gamma_array_ = select_all(generate_either_beta_or_gamma.gamma)
        Array[Array[File]] coerced_nested_array = [coerced_omega_array_, coerced_gamma_array_] 

		if(length(generate_either_alpha_or_omega.omega)>1 && length(generate_either_beta_or_gamma.gamma)>1) {
            #Array[File] coerced_omega_array_ = select_all(generate_either_alpha_or_omega.omega)
            #Array[File] coerced_gamma_array_ = select_all(generate_either_beta_or_gamma.gamma)
            #Array[Array[File]] coerced_nested_array = [coerced_omega_array_, coerced_gamma_array_] 
		    Array[File] coerced_omega_and_gamma_array = flatten(coerced_nested_array) 
		}

		# this if statement seems to be fine even if we move those three Array[File] definitions
		if(length(generate_either_alpha_or_omega.omega)>1) {
			Array[File] coerced_omega_array = select_all(generate_either_alpha_or_omega.omega)
		}

		if(length(generate_either_beta_or_gamma.gamma)>1) {
			Array[File] coerced_gamma_array = select_all(generate_either_beta_or_gamma.gamma)
		}

		call check_omega_andor_gamma {
			input:
				beta_andor_gamma = select_first([coerced_omega_and_gamma_array, coerced_omega_array, coerced_gamma_array, [bogus, bogus]])
		}
	}
}

task generate_either_alpha_or_omega {
	input {
		Array[File] array_of_files
		Boolean always_succeed
	}
	command {
		always_succeed="~{always_succeed}"
		some_number=$(echo $((1 + $RANDOM % 10)))
		if [ "$always_succeed" = "false" ]
		then
			number_to_beat=5
		else
			number_to_beat=0
		fi
		if (( $some_number > $number_to_beat ))
		then
			touch alpha
			echo "alpha - success ($some_number > $number_to_beat)"
		else
			touch omega
			echo "omega - failure ($some_number < $number_to_beat)"
		fi
	}
	runtime {
		docker: "ashedpotatoes/sranwrp:1.1.7"
		preemptible: 1
	}
    meta {
        volatile: true
    }
	output {
		File? alpha = "alpha"
		File? omega = "omega"
	}
}

task generate_either_beta_or_gamma {
	input {
		File alpha
		Boolean always_succeed
	}
	command {
		always_succeed="~{always_succeed}"
		some_number=$(echo $((1 + $RANDOM % 10)))
		if [ "$always_succeed" = "false" ]
		then
			number_to_beat=5
		else
			number_to_beat=0
		fi
		if (( $some_number > $number_to_beat ))
		then
			touch beta
			echo "beta - success ($some_number > $number_to_beat)"
		else
			mv ~{alpha} gamma
			echo "gamma - failure ($some_number < $number_to_beat)"
		fi
	}
	runtime {
		docker: "ashedpotatoes/sranwrp:1.1.7"
		preemptible: 1
	}
    meta {
        volatile: true
    }
	output {
		File? beta = "beta"
		File? gamma = "gamma"
	}
}

task check_omega_andor_gamma {
	input {
		Array[File] beta_andor_gamma
	}
	command {
		echo "Hello!"
	}
	runtime {
		docker: "ashedpotatoes/sranwrp:1.1.7"
		preemptible: 1
	}
}