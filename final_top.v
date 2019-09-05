module final_top (CLOCK_50, CLOCK2_50, KEY, FPGA_I2C_SCLK, FPGA_I2C_SDAT, AUD_XCK, 
						AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT, AUD_DACDAT, LEDR,
						SW, PS2_CLK, PS2_DAT, HEX0, HEX1);
   
	input [9:0] SW;
	input CLOCK_50, CLOCK2_50;
	input [3:0] KEY;
	output [9:0] LEDR;
	output [6:0] HEX0, HEX1;
	// I2C Audio/Video config interface
	output FPGA_I2C_SCLK;
	inout FPGA_I2C_SDAT;
	// Audio CODEC
	output AUD_XCK;
	input AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK;
	input AUD_ADCDAT;
	output AUD_DACDAT;
	
	// keyboard interface:
	inout PS2_CLK;
	inout PS2_DAT;
	
	// Local wires.
	wire read_ready, write_ready, read, write;
	wire [23:0] readdata_left, readdata_right;
	wire [23:0] writedata_left, writedata_right;
	wire reset = ~KEY[0];
	wire to;


	/////////////////////////////////
	// Your code goes here 
	/////////////////////////////////
	
	// keyboard input:
	
	wire [11:0] keys;
	
	keyboard_tracker #(.PULSE_OR_HOLD(0)) k0( // PUSLE_OR_HOLD = 0 => hold mode
	     .clock(CLOCK_50),
		  .reset(KEY[0]),
		  .PS2_CLK(PS2_CLK),
		  .PS2_DAT(PS2_DAT),
		  .a(keys[11]),
		  .w(keys[10]),
		  .s(keys[9]),
		  .e(keys[8]),
		  .d(keys[7]),
		  .f(keys[6]),
		  .t(keys[5]),
		  .g(keys[4]),
		  .y(keys[3]),
		  .h(keys[2]),
		  .u(keys[1]),
		  .j(keys[0]),
		  .left(),
		  .right(LEDR[1]),
		  .up(LEDR[2]),
		  .down(LEDR[3]),
		  .space(LEDR[8]),
		  .enter(LEDR[9])
		  );
	
	
	// main audio stuff:
	wire [23:0] audio;
	datapath d0(
				.keys(keys),
				.clk(CLOCK_50),
				.reset_n(reset),
				.oct(SW[1:0]),
				.step_seq(),
				.waveform_select(SW[2]),
				.audio_out(audio),
				.HEX_out0(HEX0),
				.HEX_out1(HEX1)
				);
	
	assign writedata_left = audio;
	assign writedata_right = audio;
	assign read = 0;
	assign write = write_ready;
	
	control c0(
        			.clk(clk),
        			.reset_n(reset),
				.to(to), 
        			.increment(~KEY[1]),
				.decrement(~KEY[2]),
        			.play_record(SW[9])
				);
	
	
/////////////////////////////////////////////////////////////////////////////////
// Audio CODEC interface. 
//
// The interface consists of the following wires:
// read_ready, write_ready - CODEC ready for read/write operation 
// readdata_left, readdata_right - left and right channel data from the CODEC
// read - send data from the CODEC (both channels)
// writedata_left, writedata_right - left and right channel data to the CODEC
// write - send data to the CODEC (both channels)
// AUD_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio CODEC
// I2C_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio/Video Config module
/////////////////////////////////////////////////////////////////////////////////
	clock_generator my_clock_gen(
		// inputs
		CLOCK2_50,
		reset,

		// outputs
		AUD_XCK
	);

	audio_and_video_config cfg(
		// Inputs
		CLOCK_50,
		reset,

		// Bidirectionals
		FPGA_I2C_SDAT,
		FPGA_I2C_SCLK
	);

	audio_codec codec(
		// Inputs
		CLOCK_50,
		reset,

		read,	write,
		writedata_left, writedata_right,

		AUD_ADCDAT,

		// Bidirectionals
		AUD_BCLK,
		AUD_ADCLRCK,
		AUD_DACLRCK,

		// Outputs
		read_ready, write_ready,
		readdata_left, readdata_right,
		AUD_DACDAT
	);

endmodule


module datapath(keys, clk, reset_n, oct, seq_step, waveform_select, audio_out, HEX_out0, HEX_out1);

	input clk, reset_n;
	input waveform_select;
	input [1:0] oct;
	input [11:0] keys;
	input [3:0] seq_step;
	output reg [23:0] audio_out;
	output [6:0] HEX_out0, HEX_out1;
   
	note_display_adapter a0(
							.keys(keys),
							.oct(oct),
							.HEX_out0(HEX_out0),
							.HEX_out1(HEX_out1)
							);
							
	wire [23:0] freq;
	freq_adapter f0(
						.keys(keys),
						.oct(oct),
						.freq(freq)
						);
	
	
	// for square wave:
   wire divided; // set to freq / 2
	
	rate_divider r0(
					.clk_in(clk),
					.reset_n(reset_n),
					.rate(freq),
					.clk_out(divided)
					);
	
	wire [23:0] square_wave;
	square_wave s0(
					.reset_n(reset_n),
					.divided_clk(divided),
					.square_audio(square_wave)
					);
	
	// for triangle wave: 
	wire [23:0] triangle_wave;
	triangle_wave t0(
						.reset_n(reset_n),
						.clk(clk),
						.rate(freq),
						.triangle_audio(triangle_wave)
						);
	
	// waveform select mux
	always @(*)
	begin
		case(waveform_select)
			1'b0: audio_out = square_wave;
			1'b1: audio_out = triangle_wave;
		endcase
	end
					
endmodule

module triangle_wave(reset_n, clk, rate, triangle_audio);
	input reset_n, clk;
	input [23:0] rate;
	output reg [23:0] triangle_audio;
	
	wire divided_clk;
	
	rate_divider r1(
						.clk_in(clk),
						.reset_n(reset_n),
						.rate(rate / 8),
						.clk_out(divided_clk)
						);
	
	localparam wave_hi = 24'b000000111111111111111111;
	
	reg [5:0] counter;
	
	always @(posedge divided_clk)
	begin
		if(reset_n) begin
			counter = 6'd0;
			triangle_audio = 24'd0;
		end
		else begin
			if(counter < 6'd8)  
				triangle_audio <= triangle_audio + wave_hi / 8;
			else begin
				counter <= 6'd0;
				triangle_audio <= 24'd0;
			end
			
			counter <= counter + 1;
				
		end
	end
	
	
endmodule

module square_wave(reset_n, divided_clk, square_audio);
	input reset_n, divided_clk;
	output reg [23:0] square_audio;
	
	localparam wave_hi = 24'b000001111111111111111111,
				  wave_lo = 24'b000000000000000000000000;
	
	// converting the slowed clock signal into the square wave
	always @(posedge divided_clk)
	begin
		if(reset_n)
			square_audio <= 24'd0;
		else begin
			if(square_audio == wave_hi)
				square_audio <= wave_lo;
			else //if(audio == wave_lo)
				square_audio <= wave_hi;
		end
	end

endmodule



module freq_adapter(keys, oct, freq);
	input [11:0] keys; // key currently being pressed
	input [1:0] oct; // octave
	output reg [23:0] freq; // specifies the frequency to the rate divider
	
	always @(*)
	begin
		case(keys)
			12'b100000000000: freq = 20'b01011101010100011010 / (2**oct); // C
			12'b010000000000: freq = 20'b01011000000101001000 / (2**oct); // C#
			12'b001000000000: freq = 20'b01010011001000110010 / (2**oct); // D
			12'b000100000000: freq = 20'b01001110011110001011 / (2**oct); // D#
			12'b000010000000: freq = 20'b01001010000100010100 / (2**oct); // E
			12'b000001000000: freq = 20'b01000101111010010000 / (2**oct); // F
			12'b000000100000: freq = 20'b01000001111110111110 / (2**oct); // F#
			12'b000000010000: freq = 20'b00111110010001111110 / (2**oct); // G
			12'b000000001000: freq = 20'b00111010110010010110 / (2**oct); // G#
			12'b000000000100: freq = 20'b00110111011111001001 / (2**oct); // A
			12'b000000000010: freq = 20'b00110100010111110111 / (2**oct); // A#
			12'b000000000001: freq = 20'b00110001011011101110 / (2**oct); // B
			default : freq = 24'd0;
		endcase
	end

endmodule

module rate_divider(clk_in, reset_n, rate, clk_out);
	input clk_in;
	input reset_n;
	input [23:0] rate;
	output clk_out;
	
	reg [23:0] q;
	
	always @(posedge clk_in) 
	begin
		if (reset_n) 
			q <= 24'd0 ; 
		else if (q == 24'd0) 
			q <= rate;
		else 
			q <= q - 1'b1 ;
	end
	
	assign clk_out = (q == 24'd0) ? 1 : 0;
	
endmodule

module note_display_adapter(keys, oct, HEX_out0, HEX_out1);
	input [11:0] keys; // key currently being pressed
	input [1:0] oct; // octave
	output reg [6:0] HEX_out0; // displays sharp or flat 
	output reg [6:0] HEX_out1; // displays the current note being played
	
	localparam sharp = 7'b0011100,
				  natural = 7'b1111111;
	
	always @(*)
	begin
		case(keys)
			12'b100000000000: begin 
				HEX_out0 =  natural; // C
				HEX_out1 = 7'b1000110; end
			12'b010000000000: begin 
				HEX_out0 =  sharp; // C#
				HEX_out1 = 7'b1000110; end
			12'b001000000000: begin
				HEX_out0 =  natural; // D
				HEX_out1 = 7'b0100001; end
			12'b000100000000: begin 
				HEX_out0 =  sharp; // D#
				HEX_out1 = 7'b0100001; end 
			12'b000010000000: begin
				HEX_out0 =  natural; // E
				HEX_out1 = 7'b0000110; end 
			12'b000001000000: begin
				HEX_out0 =  natural; // F
				HEX_out1 = 7'b0001110; end 
			12'b000000100000: begin
				HEX_out0 =  sharp; // F#
				HEX_out1 = 7'b0001110; end 
			12'b000000010000: begin
				HEX_out0 =  natural; // G
				HEX_out1 = 7'b1000010; end 
			12'b000000001000: begin
				HEX_out0 =  sharp; // G#
				HEX_out1 = 7'b1000010; end 
			12'b000000000100: begin
				HEX_out0 =  natural; // A
				HEX_out1 = 7'b0001000; end 
			12'b000000000010: begin
				HEX_out0 =  sharp; // A#
				HEX_out1 = 7'b0001000; end 
			12'b000000000001: begin 
				HEX_out0 =  natural; // B
				HEX_out1 = 7'b0000011; end
			default: begin 
				HEX_out0 =  7'b1111111;
				HEX_out1 = 7'b1111111; end 
		endcase
	end
endmodule


module control(clk, reset_n, to, increment, decrement, play_record, write, step_number);
	input clk; 
	input reset_n;
	input [1:0] increment;
	input [1:0] decrement;
	input [1:0] play_record;
	input to;
	
	output reg [1:0] write;
	output reg [3:0] step_number;
	
	reg [4:0] current_state, next_state;
	
	localparam  start_state = 4'd0,
		    NOTE_1 = 4'd1,
               	    NOTE_2 = 4'd2,
                    NOTE_3 = 4'd3,
                    NOTE_4 = 4'd4,
                    NOTE_5 = 4'd5,
                    NOTE_6 = 4'd6,
                    NOTE_7 = 4'd7,
                    NOTE_8 = 4'd8,
                    before_play = 4'd9,
                    playback = 4'd10;
	always@(*)
    	begin: state_table
           	 case (current_state)
                	start_state: next_state = to ? (NOTE_1 ? increment : decrement) : (start_state ? increment : decrement); 
                	NOTE_1: next_state = to ? (NOTE_2 ? increment : decrement) : (start_state ? increment : decrement);
                	NOTE_2: next_state = to ? (NOTE_3 ? increment : decrement) : (NOTE_1 ? increment : decrement);
                	NOTE_3: next_state = to ? (NOTE_4 ? increment : decrement) : (NOTE_2 ? increment : decrement);
			NOTE_4: next_state = to ? (NOTE_5 ? increment : decrement) : (NOTE_3 ? increment : decrement);
			NOTE_5: next_state = to ? (NOTE_6 ? increment : decrement) : (NOTE_4 ? increment : decrement);
			NOTE_6: next_state = to ? (NOTE_7 ? increment : decrement) : (NOTE_5 ? increment : decrement);
			NOTE_7: next_state = to ? (NOTE_8 ? increment : decrement) : (NOTE_6 ? increment : decrement);
			NOTE_8: next_state = to ? (before_play ? increment : decrement) : (NOTE_7 ? increment : decrement);
			before_play: next_state = playback;	 
           	 default:     next_state = start_state;
        	endcase
    	end
	 
	always @(*)
    	begin: enable_signals
       	 	step_number = 1'd0;
		write = 1'd1;

        case (current_state)
            start_state: begin
                step_number = 1'd0;
                end
            NOTE_1: begin
                step_number = 1'd1;
                end
            NOTE_2: begin
                step_number = 1'd2;
                end
			NOTE_3: begin
                step_number = 1'd3;
                end
				NOTE_4: begin
                step_number = 1'd4;
                end
				NOTE_5: begin
                step_number = 1'd5;
                end
				NOTE_6: begin
                step_number = 1'd6;
                end
				NOTE_7: begin
                step_number = 1'd7;
                end
				NOTE_8: begin
                step_number = 1'd8;
                end
				before_play: begin
					 write = 1'd0;
                step_number = 1'd0;
                end
				playback: begin
					write = 1'd0
					step_number = 1'd0
					 end
        endcase
    end
	 
	 always@(posedge clk)
    begin: state_FFs
        if(reset_n)
            current_state <= start_state;
        else
            current_state <= next_state;
    end

endmodule 
