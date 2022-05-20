all:
	
	iverilog -o strb2mask.out  testbench.v strb2mask.v
	vvp -n strb2mask.out

wave:
	gtkwave *.vcd &
clean:
	rm *.out *.vcd *.vvp
