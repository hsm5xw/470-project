// cache mem 32x64

//`timescale 1ns/100ps

module dcachemem(
	input  logic clock, reset, 

	/////////////// INPUTS ////////////////////////////////////////////////////
	input  logic			wr1_req_en,
	input  logic			wr1_missed_load_en,

	input  logic [`INDEX_BITS-1:0] 	wr1_req_idx,	   	// write from SQ request
	input  logic [`TAG_BITS-1:0] 	wr1_req_tag,  	   	
	input  logic [63:0]   		wr1_req_data,	   	// data  from SQ request

	input  logic [`INDEX_BITS-1:0] 	wr1_missed_load_idx,	// write from previously missed load
	input  logic [`TAG_BITS-1:0] 	wr1_missed_load_tag,  				
	
	input  logic [`INDEX_BITS-1:0] 	rd1_idx,  	   	// read index
	input  logic [`TAG_BITS-1:0] 	rd1_tag,  	   	// read tag

	input  logic [63:0]		wr1_data_from_Mem,	// data coming directly from Memory
	input  CACHE_COMMAND  		proc2Dcache_command_1,

	/////////////// OUTPUTS ////////////////////////////////////////////////////
	output logic [63:0] 	rd1_data,
	output logic	 	rd1_valid
);

	CACHE_SET [`NUM_SETS-1:0] cache;

	logic [`CACHE_ASSOC_BITS-1:0]    wr1_access_line;	// index of line (way) in set associative cache where you access to replace, upon a write
	logic [`CACHE_ASSOC_BITS-1:0]    rd1_access_line;	// index of line (way) in set associative cache where you access to replace, upon a read
	logic [`CACHE_ASSOC_BITS-1:0]    wr1_trump_access_line;	// index of line (way) in set associative cache where you access to replace, upon a write

	logic [`CACHE_ASSOC_BITS:0]	 n_wr1_pseudo_LRU_bits;
	logic [`CACHE_ASSOC_BITS:0]	 n_rd1_pseudo_LRU_bits;

	// trump card !!!!!!
	logic [`CACHE_ASSOC_BITS:0]	 trump_LRU_bits;
	logic [`CACHE_ASSOC_BITS:0]	 n_trump_LRU_bits;
	logic [1:0]  			 trump_en;

	CACHE_SET    rd1_set;
	CACHE_SET    wr1_set;
	CACHE_SET    wr1_missed_load_set;

	logic wr1_hit;
	logic rd1_hit;

	always_comb begin

		// Read data from cache
		rd1_set = cache[rd1_idx];		// cash set 
		rd1_data 	= 64'hDEAD_DEAD_DEAD_DEAD;
		rd1_valid 	= 1'b0;
		rd1_access_line = 0;

		// Write data on cache
		wr1_set = cache[ wr1_req_idx];		// cash set
		wr1_access_line = 0;	

		// Write data on cache on Missed load	
		wr1_missed_load_set = cache[ wr1_missed_load_idx];
		wr1_trump_access_line = 0;


		// Update the pseudo_LRU_bits upon Read Hits and Writes
		n_rd1_pseudo_LRU_bits 	= rd1_set.pseudo_LRU_bits;
		n_wr1_pseudo_LRU_bits 	= wr1_set.pseudo_LRU_bits;

		// trump card !!!!!!
		n_trump_LRU_bits 	= wr1_set.pseudo_LRU_bits; // &&&&&&&&&&&&&&
		trump_en		= 0;

		// Hits
		wr1_hit = 0;
		rd1_hit = 0;

			
		// only valid if the command is LOAD. if it is COMMAND_NONE it's invalid
		if ( proc2Dcache_command_1 == COMMAND_LOAD ) 	 
		begin	
			// Update the pseudo_LRU_bits upon read Hits
			n_rd1_pseudo_LRU_bits 	= rd1_set.pseudo_LRU_bits;

			// default access line
			if( rd1_set.pseudo_LRU_bits[2] ) begin	 // If the MSB of the pseudo_LRU_bits is 1, grab the MSB and LSB	
				rd1_access_line = { rd1_set.pseudo_LRU_bits[2], rd1_set.pseudo_LRU_bits[0] };
			end			
			else begin			  	// else grab the two MSB's
				rd1_access_line = { rd1_set.pseudo_LRU_bits[2], rd1_set.pseudo_LRU_bits[1] };
			end

			// get a hit index for the read request. Upon a hit, the default access line is overriden  
			for(int i=0; i < `CACHE_ASSOC; i++) begin

				if( (rd1_set.line[i].valid) && (rd1_set.line[i].tag == rd1_tag) ) begin

					rd1_data 	 = rd1_set.line[i].data;
					rd1_valid 	 = 1'b1;	// read hit
					rd1_access_line  = i;		// upon hit, update (***) the access line

					// Update the pseudo-LRU bits for the corresponding cache set
					if( rd1_access_line[1] ) begin  // If the MSB of the access way is 1, flip the bits on MSB and LSB 

						n_rd1_pseudo_LRU_bits[2] = ~rd1_access_line[1];
						n_rd1_pseudo_LRU_bits[0] = ~rd1_access_line[0];
					end
					else begin			// else flip the bits on the two MSB's
						n_rd1_pseudo_LRU_bits[2] = ~rd1_access_line[1]; 
						n_rd1_pseudo_LRU_bits[1] = ~rd1_access_line[0];
					end
				end			
			end // end of read hit			
		end // end of if
		

		// Write data on Cache from SQ request
		if( wr1_req_en ) 
		begin			
			// default access line
			if( wr1_set.pseudo_LRU_bits[2] ) begin	  // If the MSB of the pseudo_LRU_bits is 1, grab the MSB and LSB	
				wr1_access_line = { wr1_set.pseudo_LRU_bits[2], wr1_set.pseudo_LRU_bits[0] };
			end			
			else begin			  	  // else grab the two MSB's
				wr1_access_line = { wr1_set.pseudo_LRU_bits[2], wr1_set.pseudo_LRU_bits[1] };
			end
		
			// get a hit index for the write request. Upon a hit, the default access line is overriden  
			for(int i=0; i < `CACHE_ASSOC; i++) begin	
				if( (wr1_set.line[i].valid) && (wr1_set.line[i].tag == wr1_req_tag)  ) begin
					wr1_access_line = i;	  // upon hit, update (***) the access line
					wr1_hit	 	= 1;
				end				
			end
			
			// Update the pseudo-LRU bits for the corresponding cache set
			if( wr1_access_line[1] ) begin  // If the MSB of the access way is 1, flip the bits on MSB and LSB 

				n_wr1_pseudo_LRU_bits[2] = ~wr1_access_line[1];
				n_wr1_pseudo_LRU_bits[0] = ~wr1_access_line[0];
			end

			else begin			// else flip the bits on the two MSB's
				n_wr1_pseudo_LRU_bits[2] = ~wr1_access_line[1]; 
				n_wr1_pseudo_LRU_bits[1] = ~wr1_access_line[0];
			end

		end // end if


		// Write data on cache from Missed Load		
		if( wr1_missed_load_en ) 
		begin	
			wr1_missed_load_set = cache[ wr1_missed_load_idx];	// cash set

			// Update the pseudo_LRU_bits upon Writes
			if( rd1_hit && (wr1_missed_load_idx == rd1_idx) ) begin
				trump_LRU_bits 	= n_rd1_pseudo_LRU_bits;
				trump_en 	= 2'b10;
			end 
			else if( wr1_req_en && (wr1_missed_load_idx == wr1_req_idx) ) begin
				trump_LRU_bits 	= n_wr1_pseudo_LRU_bits;
				trump_en	= 2'b01;
			end
			else begin
				trump_LRU_bits 	= wr1_missed_load_set.pseudo_LRU_bits;
				trump_en	= 2'b00;	
			end

			// default access line
			if( trump_LRU_bits[2] ) begin	  // If the MSB of the pseudo_LRU_bits is 1, grab the MSB and LSB	
				wr1_trump_access_line = { trump_LRU_bits[2], trump_LRU_bits[0] };
			end			
			else begin			  	  // else grab the two MSB's
				wr1_trump_access_line = { trump_LRU_bits[2], trump_LRU_bits[1] };
			end

			/*
			// get a hit index for the write request. Upon a hit, the default access line is overriden  
			for(int i=0; i < `CACHE_ASSOC; i++) begin	
				if( (wr1_set.line[i].valid) && (wr1_set.line[i].tag == wr1_missed_load_tag)  ) begin
					wr1_access_line = i;	// upon hit, update (***) the access line
				end				
			end
			*/

			n_trump_LRU_bits = trump_LRU_bits;

			// Update the pseudo-LRU bits for the corresponding cache set
			if( wr1_trump_access_line[1] ) begin  // If the MSB of the access way is 1, flip the bits on MSB and LSB 

				n_trump_LRU_bits[2] = ~wr1_trump_access_line[1];
				n_trump_LRU_bits[0] = ~wr1_trump_access_line[0];
			end

			else begin			// else flip the bits on the two MSB's
				n_trump_LRU_bits[2] = ~wr1_trump_access_line[1]; 
				n_trump_LRU_bits[1] = ~wr1_trump_access_line[0];
			end
			

		end // end if

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock)
	begin
		if(reset) 
		begin
			// Upon reset, invalidate all cache lines
			for(int i=0; i < `NUM_SETS; i++) begin
				for(int j=0; j < `CACHE_ASSOC; j++) begin
					cache[i].line[j].valid <= `SD 1'b0;
				end

				cache[i].pseudo_LRU_bits <= `SD 0;
			end
		end
		else begin
			// LOAD_HIT
			if( (proc2Dcache_command_1 == COMMAND_LOAD) && rd1_valid)  
			begin
				if( trump_en == 2'b10 ) begin
					cache[ rd1_idx].pseudo_LRU_bits 		<= `SD n_trump_LRU_bits;
				end else begin
					cache[ rd1_idx].pseudo_LRU_bits 		<= `SD n_rd1_pseudo_LRU_bits;
				end 			
			end

			// STORE_FROM_REQ
			if ( wr1_req_en) 	
			begin
				if( trump_en == 2'b01 ) begin
					cache[ wr1_req_idx].pseudo_LRU_bits 			<= `SD n_trump_LRU_bits; 	// update the pseudo_LRU_bits

					cache[ wr1_req_idx].line[ wr1_access_line].valid	<= `SD 1'b1;			// validate the cache line
					cache[ wr1_req_idx].line[ wr1_access_line].data		<= `SD	wr1_req_data;		// write data from Write Request
					cache[ wr1_req_idx].line[ wr1_access_line].tag		<= `SD  wr1_req_tag;
				end else begin
					cache[ wr1_req_idx].pseudo_LRU_bits 			<= `SD n_wr1_pseudo_LRU_bits; 	// update the pseudo_LRU_bits

					cache[ wr1_req_idx].line[ wr1_access_line].valid	<= `SD 1'b1;			// validate the cache line
					cache[ wr1_req_idx].line[ wr1_access_line].data		<= `SD	wr1_req_data;		// write data from Write Request
					cache[ wr1_req_idx].line[ wr1_access_line].tag		<= `SD  wr1_req_tag;
				end					
		
			end
	
			
			// STORE_FROM_MEM 
			if( wr1_missed_load_en)  
			begin
				cache[ wr1_missed_load_idx].pseudo_LRU_bits 			<= `SD n_trump_LRU_bits; 	
				cache[ wr1_missed_load_idx].line[ wr1_trump_access_line].valid	<= `SD 1'b1;			

				cache[ wr1_missed_load_idx].line[ wr1_trump_access_line].data	<= `SD wr1_data_from_Mem;	// write data from Memory
				cache[ wr1_missed_load_idx].line[ wr1_trump_access_line].tag	<= `SD wr1_missed_load_tag;						
			end
			
		end
	end
endmodule
