//     %%%%%%%%%%%%      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  %%%%%%%%%%%%%%%%%%                      
// %%%%%%%%%%%%%%%%%%%% %%                
//    %% %%%%%%%%%%%%%%%%%%                
//        % %%%%%%%%%%%%%%%                 
//           %%%%%%%%%%%%%%                 ////    O P E N - S O U R C E     ////////////////////////////////////////////////////////////
//           %%%%%%%%%%%%%      %%          _________________________________////
//           %%%%%%%%%%%       %%%%                ________    _                             __      __                _     
//          %%%%%%%%%%        %%%%%%              / ____/ /_  (_)___  ____ ___  __  ______  / /__   / /   ____  ____ _(_)____ TM 
//         %%%%%%%    %%%%%%%%%%%%*%%%           / /   / __ \/ / __ \/ __ `__ \/ / / / __ \/ //_/  / /   / __ \/ __ `/ / ___/
//        %%%%% %%%%%%%%%%%%%%%%%%%%%%%         / /___/ / / / / /_/ / / / / / / /_/ / / / / ,<    / /___/ /_/ / /_/ / / /__  
//       %%%%*%%%%%%%%%%%%%  %%%%%%%%%          \____/_/ /_/_/ .___/_/ /_/ /_/\__,_/_/ /_/_/|_|  /_____/\____/\__, /_/\___/
//       %%%%%%%%%%%%%%%%%%%    %%%%%%%%%                   /_/                                              /____/  
//       %%%%%%%%%%%%%%%%                                                             ___________________________________________________               
//       %%%%%%%%%%%%%%                    //////////////////////////////////////////////       c h i p m u n k l o g i c . c o m    //// 
//         %%%%%%%%%                       
//           %%%%%%%%%%%%%%%%               
//    
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : arbiter_rrobin.sv
//----%% Module Name      : Round-Robin Arbiter                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Classic Round-Robin Arbiter to resolve requests from N devices with round-robin scheduling. Only one device at a time 
//----%%                    is issued grant. The device requests are arbitrated in a circular queue:
//----%%
//----%%                    +<------------------<-------------------<--+
//----%%                    |                                          |
//----%%                    + --> [0] --> [1] --> [2] ... --> [N-1] -->+
//----%%                           ^
//----%%                           |
//----%%                          HEAD on reset
//----%%                        
//----%%                    Round-robin ensures that every requester receives an equal opportunity to be granted by rotating the highest priority 
//----%%                    after each grant.
//----%%                    HEAD has the highest priority.
//----%%                    HEAD moves from [x]-->[x+1] in the circular queue when-
//----%%                    - The device@HEAD has been issued a grant.
//----%%                    - The device@HEAD has no pending request, forcing the arbiter to skip to the next active requester
//----%%                    Ensures fairness by assigning lowest priority to the last served device.
//----%%                    No grant cycle is wasted as long as there is at least one device is requesting.
//----%%
//----%% Last modified on : Dec-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see README.md
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                               A R B I T E R   -   R O U N D -  R O B I N                                         
//###################################################################################################################################################
`timescale 1ns/1ps

`default_nettype none
module arbiter_rrobin (
   input  logic [0:0]      clk     ,  // Clock
   input  logic [0:0]    aresetn ,  // Async active-low reset
   input  logic [3:0] i_req   ,  // Requests
   output logic [3:0] o_grant    // Grants
);

// Internal Signals/Registers
logic [3:0] masked_req, masked_grant ;  // Masked Request & Grant
logic [3:0] priority_sel_grant       ;  // Priority selected Grant
logic [3:0] mask_rg                  ;  // Mask register

// Mask generation logic
// Assume one clock cycle = one time slot...
// Generate new mask once a device is issued grant and mask the device...
// '0' masks the request
always_ff @(posedge clk or negedge aresetn) begin 
//always @(posedge clk ) begin 
   if (!aresetn) begin
      mask_rg <= 4'hF ;  // HEAD at [0] on reset
   end 
   else begin
      if      (o_grant[0]) mask_rg <= 4'b1110 ;  // HEAD becomes [1] after issuing grant at [0]
      else if (o_grant[1]) mask_rg <= 4'b1100 ;  // HEAD becomes [2] after issuing grant at [1]
      else if (o_grant[2]) mask_rg <= 4'b1000 ;  // HEAD becomes [3] after issuing grant at [2]
      else if (o_grant[3]) mask_rg <= 4'b1111 ;  // HEAD resets to [0] after issuing grant at [3]    
   end     
end

// Masked Request: masks all served devices/lower priority devices at [0] to [HEAD-1]
//                 The devices at HEAD to [N-1] are unmasked...
assign masked_req = i_req & mask_rg ;

// Masked Grant: grant corresponding to Masked Request
arbiter_fx_priority #(
   .N (4)
) inst_masked_grant (
   .i_req   (masked_req) , 
   .o_grant (masked_grant)
);

// Priority selected Grant: grant corresponding to Unmasked Request, this acts like fixed priority arbiter...
arbiter_fx_priority #(
   .N (4)
) inst_priority_sel_grant (
   .i_req   (i_req) , 
   .o_grant (priority_sel_grant)
);

// Final Grant
// ===========
// clk      /````\____/````\____/````\____/````\____/````\____/
// D0_req   /`````````````````````````````````````````````````\
// D1_req   /`````````````````````````````````````````````````\
// D2_req   /`````````````````````````````````````````````````\
// D3_req   /`````````````````````````````````````````````````\
// D0_grant /`````````\_____________________________/`````````\
// D1_grant __________/`````````\______________________________
// D2_grant ____________________/`````````\____________________
// D3_grant ______________________________/`````````\__________
//
// If no requests are pending from any devices at HEAD to [N-1], arbitrate across all devices at [0] to [N-1]
// clk      /````\____/````\____/````\____/````\____/
// D0_req   /```````````````````````````````````````\
// D1_req   /```````````````````````````````````````\
// D2_req   _________________________________________
// D3_req   _________________________________________
// D0_grant /`````````\_________/`````````\_________/
// D1_grant __________/`````````\_________/`````````\
// D2_grant _________________________________________
// D3_grant _________________________________________
//
assign o_grant = (|masked_req)? masked_grant : priority_sel_grant ;


`ifdef FORMAL
//default clocking Clk @(posedge clk);
//endclocking

logic f_past_valid;
initial f_past_valid=0;
always @(posedge clk)
	f_past_valid <= 1'b1;

always @(posedge clk)
    if(!f_past_valid)
	assume(aresetn==0);

// assume property (   @(posedge clk)  (~clk) == $past(clk));
logic   [1:0] idx, head;

//assume_sym_idx: assume property ( @(posedge clk) disable iff(!aresetn)  ##1 $stable(idx)  );
 assume_sym_idx: assume property ( @(posedge clk) disable iff(!aresetn)  f_past_valid  |-> idx==$past(idx)  );

//assume_input: assume property( @(posedge clk) disable iff(!aresetn) (i_req[idx] && !o_grant[idx] ) |=> i_req[idx]   );
assume_input: assume property (@(posedge clk) disable iff (!aresetn)   f_past_valid &&   $past(i_req[idx] && !o_grant[idx] )   |->  i_req[idx]);

assume_invariant :assume property (@(posedge clk) disable iff (!aresetn)
		  (head == 2'b00 && mask_rg == 4'b1111) ||
 		  (head == 2'b01 && mask_rg == 4'b1110) ||
 		  (head == 2'b10 && mask_rg == 4'b1100) ||
 	 	  (head == 2'b11 && mask_rg == 4'b1000));

//genvar j;
//generate 
//for(j=0 ;j<4;j++) begin :gen
//asssume_in: assume property( @(posedge clk) disable iff(!aresetn) (i_req[j] && !o_grant[j] ) |=> i_req[j]   );
//end 
//endgenerate

///// round robin head priority based on prev gnt /////////////////////

always @(posedge clk,negedge aresetn ) begin
   if(!aresetn) 
    head <= 2'b00;
  else  begin 
    if(o_grant[0])  head <= 2'b01;
    if(o_grant[1])  head <= 2'b10;
    if(o_grant[2])  head <= 2'b11;
    if(o_grant[3])  head <= 2'b00;
  end 
end 


assert_head_grant : assert property ( @(posedge clk) disable iff(!aresetn)  head == idx && i_req[idx] |->  o_grant[idx]  );

assert_inv_grant_req : assert property ( @(posedge clk) disable iff(!aresetn)    o_grant[idx] && head == idx  |->   i_req[idx]  );

assert_head_grant_low : assert property ( @(posedge clk) disable iff(!aresetn)  (head == idx && (!i_req[idx]) )  |->  (!o_grant[idx] ) );
 
assert_head_next_grant : assert property ( @(posedge clk) disable iff(!aresetn)  (  head == idx && (!i_req[idx]  && i_req[idx+1'b1] ) )  |->  (!o_grant[idx] && o_grant[idx+1'b1] ) );

cover_head_next_grant : cover property ( @(posedge clk) disable iff(!aresetn)  ( head == idx && (!i_req[idx]  && i_req[idx+1'b1] ) )  &&  ( !o_grant[idx] && o_grant[idx+1'b1] ) );


//cover_req_changed : cover property(  @(posedge clk)  ##1$changed(  i_req )  );

cover_all_req : cover property ( @(posedge clk) disable iff(!aresetn)  ( &i_req == 1 ));
cover_no_req : cover property ( @(posedge clk) disable iff(!aresetn)  ( |i_req == 0 ));

cover_grant0 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[0] ));
cover_grant1 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[1] ));
cover_grant2 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[2] ));
cover_grant3 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[3] ));


assert_onehot0_grant: assert property (@(posedge clk) disable iff(!aresetn)  ( $countones(o_grant) == 1)  || ($countones(o_grant) == 0) );// onehot0
 
cover_onehot_grant: cover property(@(posedge clk) disable iff(!aresetn)   ( (|o_grant == 1) && (o_grant & (o_grant-1'b1)) == 0   )     );  // onehot

cover_no_grant:  cover property(@(posedge clk) disable iff(!aresetn)   $countones(o_grant) == 0); 


//genvar i;
//generate 
//for(i=0 ;i<4;i++) begin :gen
//ass3: assert property( @(posedge clk) disable iff(!aresetn) (i_req[i] && !o_grant[i] ) |=> i_req[i]   );
//end 
//endgenerate

assert_req_dont_retreat: assert property( @(posedge clk) disable iff(!aresetn)  f_past_valid && $past(i_req[idx] && !o_grant[idx] ) |-> i_req[idx]   );

`endif

endmodule
//###################################################################################################################################################
//                                               A R B I T E R   -   R O U N D -  R O B I N                                         
//###################################################################################################################################################


