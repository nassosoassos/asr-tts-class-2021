import sys

input_filename = sys.argv[1]
output_filename = sys.argv[2]

with open(input_filename, 'r') as input_file:
    with open(output_filename, 'w') as output_file:
        for line in input_file:
            cline = line.rstrip()
            info = cline.split(' ')
            output_file.write(" ".join(info[1:])+" ({})\n".format(info[0]))
